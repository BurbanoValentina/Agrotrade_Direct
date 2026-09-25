-- ==============================================================================
-- AgroTrade Direct — Migración 0003: Control de acceso por rol (RBAC)
-- REQ-24: Seguridad y control de acceso por rol.
-- Soporte para REQ-29 (cuenta tester) y REQ-33 (panel de administrador).
--
-- * staff_members: empleados del panel admin con permisos granulares. Inician
--   sesión con Supabase Auth como cualquier usuario (sin contraseñas propias).
-- * blocked_users: bloqueo real desde la base de datos.
-- * profiles.is_tester: marca de la cuenta QA; solo la cambia un admin.
-- ==============================================================================

-- ==============================================================================
-- 1. ROL 'staff' EN PROFILES Y CAMPO is_tester
-- ==============================================================================
-- Los empleados también tienen perfil (lo crea el trigger de registro). Se les
-- asigna el rol 'staff' para que no puedan publicar ofertas ni negociar.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('exportador', 'importador', 'staff'));

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_tester BOOLEAN NOT NULL DEFAULT false;

-- Nadie puede registrarse como 'staff' desde la app: el registro solo acepta
-- exportador o importador (cualquier otro valor cae en importador).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT := NEW.raw_user_meta_data->>'role';
BEGIN
  IF v_role IS NULL OR v_role NOT IN ('exportador', 'importador') THEN
    v_role := 'importador';
  END IF;

  INSERT INTO public.profiles (id, role, name, email, company_name, country)
  VALUES (
    NEW.id,
    v_role,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    NEW.email,
    NEW.raw_user_meta_data->>'company_name',
    NEW.raw_user_meta_data->>'country'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ==============================================================================
-- 2. TABLA: staff_members (empleados del panel admin)
-- ==============================================================================
-- Los valores de permissions coinciden con el enum AdminPermission de Flutter
-- (lib/models/admin_permission.dart).
CREATE TABLE IF NOT EXISTS public.staff_members (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_super_admin BOOLEAN NOT NULL DEFAULT false,
  permissions TEXT[] NOT NULL DEFAULT '{}' CHECK (
    permissions <@ ARRAY[
      'dashboard', 'userManagement', 'employeeManagement', 'offerManagement',
      'negotiationManagement', 'reports', 'settings', 'security'
    ]::TEXT[]
  ),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

DROP TRIGGER IF EXISTS set_staff_members_updated_at ON public.staff_members;
CREATE TRIGGER set_staff_members_updated_at
  BEFORE UPDATE ON public.staff_members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ==============================================================================
-- 3. TABLA: blocked_users
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.blocked_users (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (length(trim(reason)) > 0),
  blocked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  blocked_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 4. FUNCIONES DE AYUDA PARA LAS POLÍTICAS
-- ==============================================================================
-- SECURITY DEFINER para leer staff_members / blocked_users sin depender de sus
-- propias políticas (evita recursión). La app también puede llamarlas por RPC:
--   supabase.rpc('is_staff')  /  supabase.rpc('has_permission', params: {'p_permission': 'security'})
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.staff_members
    WHERE user_id = auth.uid() AND is_active
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.has_permission(p_permission TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.staff_members
    WHERE user_id = auth.uid()
      AND is_active
      AND (is_super_admin OR p_permission = ANY (permissions))
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_blocked()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM public.blocked_users WHERE user_id = auth.uid());
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.is_staff(), public.has_permission(TEXT), public.is_blocked() FROM anon;

-- ==============================================================================
-- 5. REGLAS DE staff_members (evitar escalada de privilegios)
-- ==============================================================================
--   * Nadie puede modificar sus propios permisos.
--   * Solo un super admin puede crear, editar o quitar otro super admin.
--   * Un admin normal solo puede otorgar permisos que él mismo tiene.
-- Las operaciones sin usuario (SQL Editor / service_role) no se restringen:
-- así se crea el primer super admin.
CREATE OR REPLACE FUNCTION public.enforce_staff_rules()
RETURNS TRIGGER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_caller public.staff_members%ROWTYPE;
  v_target public.staff_members%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_target := OLD;
  ELSE
    v_target := NEW;
  END IF;

  SELECT * INTO v_caller FROM public.staff_members WHERE user_id = v_uid;

  IF v_target.user_id = v_uid THEN
    RAISE EXCEPTION 'No puedes modificar tus propios permisos';
  END IF;

  IF NOT COALESCE(v_caller.is_super_admin, false) THEN
    IF v_target.is_super_admin OR (TG_OP = 'UPDATE' AND OLD.is_super_admin) THEN
      RAISE EXCEPTION 'Solo un super admin puede gestionar a otro super admin';
    END IF;
    IF TG_OP <> 'DELETE' AND NOT (NEW.permissions <@ v_caller.permissions) THEN
      RAISE EXCEPTION 'No puedes otorgar permisos que no tienes';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.created_by := v_uid;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS enforce_staff_rules ON public.staff_members;
CREATE TRIGGER enforce_staff_rules
  BEFORE INSERT OR UPDATE OR DELETE ON public.staff_members
  FOR EACH ROW EXECUTE FUNCTION public.enforce_staff_rules();

-- Al registrar un empleado, su perfil pasa a rol 'staff'.
CREATE OR REPLACE FUNCTION public.mark_profile_as_staff()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles SET role = 'staff' WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS mark_profile_as_staff ON public.staff_members;
CREATE TRIGGER mark_profile_as_staff
  AFTER INSERT ON public.staff_members
  FOR EACH ROW EXECUTE FUNCTION public.mark_profile_as_staff();

REVOKE EXECUTE ON FUNCTION public.enforce_staff_rules(), public.mark_profile_as_staff()
  FROM PUBLIC, authenticated, anon;

-- ==============================================================================
-- 6. RPC: marcar cuenta tester (REQ-29)
-- ==============================================================================
-- is_tester no es editable por UPDATE directo (permisos por columna de la
-- migración base), así que el admin lo cambia con esta función:
--   supabase.rpc('set_tester', params: {'p_user_id': id, 'p_is_tester': true})
CREATE OR REPLACE FUNCTION public.set_tester(p_user_id UUID, p_is_tester BOOLEAN)
RETURNS VOID AS $$
BEGIN
  IF NOT public.has_permission('userManagement') THEN
    RAISE EXCEPTION 'Requiere el permiso userManagement';
  END IF;
  UPDATE public.profiles SET is_tester = p_is_tester WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.set_tester(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_tester(UUID, BOOLEAN) TO authenticated;

-- ==============================================================================
-- 7. POLÍTICAS: staff_members y blocked_users
-- ==============================================================================
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Cada empleado ve su propia fila (la app la usa para saber sus permisos);
-- quien gestiona empleados ve todas.
DROP POLICY IF EXISTS "Staff can view themselves or manage employees" ON public.staff_members;
CREATE POLICY "Staff can view themselves or manage employees"
  ON public.staff_members FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.has_permission('employeeManagement'));

DROP POLICY IF EXISTS "Employee managers can add staff" ON public.staff_members;
CREATE POLICY "Employee managers can add staff"
  ON public.staff_members FOR INSERT
  TO authenticated
  WITH CHECK (public.has_permission('employeeManagement'));

DROP POLICY IF EXISTS "Employee managers can update staff" ON public.staff_members;
CREATE POLICY "Employee managers can update staff"
  ON public.staff_members FOR UPDATE
  TO authenticated
  USING (public.has_permission('employeeManagement'))
  WITH CHECK (public.has_permission('employeeManagement'));

DROP POLICY IF EXISTS "Employee managers can remove staff" ON public.staff_members;
CREATE POLICY "Employee managers can remove staff"
  ON public.staff_members FOR DELETE
  TO authenticated
  USING (public.has_permission('employeeManagement'));

-- El usuario bloqueado puede ver su propio bloqueo (para mostrar el motivo).
DROP POLICY IF EXISTS "Users see own block, managers see all" ON public.blocked_users;
CREATE POLICY "Users see own block, managers see all"
  ON public.blocked_users FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.has_permission('userManagement'));

DROP POLICY IF EXISTS "User managers can block" ON public.blocked_users;
CREATE POLICY "User managers can block"
  ON public.blocked_users FOR INSERT
  TO authenticated
  WITH CHECK (public.has_permission('userManagement') AND user_id <> auth.uid());

DROP POLICY IF EXISTS "User managers can update blocks" ON public.blocked_users;
CREATE POLICY "User managers can update blocks"
  ON public.blocked_users FOR UPDATE
  TO authenticated
  USING (public.has_permission('userManagement'))
  WITH CHECK (public.has_permission('userManagement'));

DROP POLICY IF EXISTS "User managers can unblock" ON public.blocked_users;
CREATE POLICY "User managers can unblock"
  ON public.blocked_users FOR DELETE
  TO authenticated
  USING (public.has_permission('userManagement'));

-- blocked_by se completa solo con el usuario que bloquea.
CREATE OR REPLACE FUNCTION public.set_blocked_by()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.blocked_by := auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS set_blocked_by ON public.blocked_users;
CREATE TRIGGER set_blocked_by
  BEFORE INSERT ON public.blocked_users
  FOR EACH ROW EXECUTE FUNCTION public.set_blocked_by();

-- ==============================================================================
-- 8. POLÍTICAS ACTUALIZADAS: los usuarios bloqueados no operan
-- ==============================================================================
DROP POLICY IF EXISTS "Exporters can create offers" ON public.offers;
CREATE POLICY "Exporters can create offers"
  ON public.offers FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = seller_id AND
    NOT public.is_blocked() AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'exportador')
  );

DROP POLICY IF EXISTS "Sellers can update their own offers" ON public.offers;
CREATE POLICY "Sellers can update their own offers"
  ON public.offers FOR UPDATE
  TO authenticated
  USING (auth.uid() = seller_id AND NOT public.is_blocked())
  WITH CHECK (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Importers can create purchase requests" ON public.negotiations;
CREATE POLICY "Importers can create purchase requests"
  ON public.negotiations FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = buyer_id AND
    buyer_id <> seller_id AND
    status = 'pending' AND
    NOT public.is_blocked() AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'importador') AND
    EXISTS (
      SELECT 1 FROM public.offers o
      WHERE o.id = negotiations.offer_id
        AND o.seller_id = negotiations.seller_id
        AND o.status IN ('activa', 'negociando')
    )
  );

DROP POLICY IF EXISTS "Parties involved can update negotiations" ON public.negotiations;
CREATE POLICY "Parties involved can update negotiations"
  ON public.negotiations FOR UPDATE
  TO authenticated
  USING ((auth.uid() = buyer_id OR auth.uid() = seller_id) AND NOT public.is_blocked())
  WITH CHECK (auth.uid() = buyer_id OR auth.uid() = seller_id);

-- ==============================================================================
-- 9. POLÍTICAS DE ADMINISTRADOR SOBRE LAS TABLAS DE NEGOCIO
-- ==============================================================================
DROP POLICY IF EXISTS "Offer managers can update any offer" ON public.offers;
CREATE POLICY "Offer managers can update any offer"
  ON public.offers FOR UPDATE
  TO authenticated
  USING (public.has_permission('offerManagement'))
  WITH CHECK (public.has_permission('offerManagement'));

DROP POLICY IF EXISTS "Offer managers can delete any offer" ON public.offers;
CREATE POLICY "Offer managers can delete any offer"
  ON public.offers FOR DELETE
  TO authenticated
  USING (public.has_permission('offerManagement'));

DROP POLICY IF EXISTS "Negotiation managers can view all negotiations" ON public.negotiations;
CREATE POLICY "Negotiation managers can view all negotiations"
  ON public.negotiations FOR SELECT
  TO authenticated
  USING (public.has_permission('negotiationManagement'));

DROP POLICY IF EXISTS "Security staff can view the full audit log" ON public.audit_log;
CREATE POLICY "Security staff can view the full audit log"
  ON public.audit_log FOR SELECT
  TO authenticated
  USING (public.has_permission('security'));

-- ==============================================================================
-- PRIMER SUPER ADMIN (ejecutar una sola vez, a mano, en el SQL Editor):
--   1. Authentication → Users → Add user (correo del admin, Auto Confirm User)
--   2. INSERT INTO public.staff_members (user_id, is_super_admin)
--      SELECT id, true FROM auth.users WHERE email = 'correo-del-admin@...';
-- ==============================================================================
