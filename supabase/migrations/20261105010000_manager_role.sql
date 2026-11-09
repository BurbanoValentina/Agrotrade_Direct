-- ==============================================================================
-- AgroTrade Direct — Migración 0013: Rol gerente (solo consulta)
-- REQ-46 (corrección de la profesora) · decisión D3: permiso explícito en la
-- base de datos, no solo en la UI.
--
-- Matriz super admin vs. gerente (documento de reparto v2):
--   Gerente SÍ: dashboard agregado, reportes de usuarios, alertas de seguridad
--               y auditoría (sin montos, REQ-47).
--   Gerente NO: bloquear/desbloquear, eliminar, advertir, resolver reportes,
--               gestionar empleados o permisos, verificar certificaciones,
--               editar platform_config ni ninguna otra acción.
--
-- Cómo se garantiza:
--   * staff_members.is_manager = true; un gerente no puede tener permisos de
--     acción ni ser super admin (CHECK).
--   * has_permission() (usado por TODAS las acciones) devuelve false para un
--     gerente, así que cualquier acción existente o futura lo rechaza.
--   * has_view_permission() abre solo las LECTURAS de la matriz; se usa en las
--     políticas de consulta del dashboard, reportes, alertas y auditoría.
-- La app lo detecta con la fila propia de staff_members (is_manager), igual
-- que el `isManager` del guard de navegación de Omar.
-- ==============================================================================

-- ==============================================================================
-- 1. MARCA DE GERENTE
-- ==============================================================================
ALTER TABLE public.staff_members
  ADD COLUMN IF NOT EXISTS is_manager BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.staff_members DROP CONSTRAINT IF EXISTS staff_members_manager_read_only;
ALTER TABLE public.staff_members
  ADD CONSTRAINT staff_members_manager_read_only CHECK (
    NOT is_manager OR (NOT is_super_admin AND permissions = '{}')
  );

-- ==============================================================================
-- 2. PERMISOS: acción vs. consulta
-- ==============================================================================
-- Acción: un gerente nunca tiene permisos de acción.
CREATE OR REPLACE FUNCTION public.has_permission(p_permission TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.staff_members
    WHERE user_id = auth.uid()
      AND is_active
      AND NOT is_manager
      AND (is_super_admin OR p_permission = ANY (permissions))
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Consulta: lo que da has_permission, más las lecturas de la matriz para el
-- gerente (dashboard, reports, security).
CREATE OR REPLACE FUNCTION public.has_view_permission(p_permission TEXT)
RETURNS BOOLEAN AS $$
  SELECT public.has_permission(p_permission) OR EXISTS (
    SELECT 1 FROM public.staff_members
    WHERE user_id = auth.uid()
      AND is_active
      AND is_manager
      AND p_permission IN ('dashboard', 'reports', 'security')
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Para la app: ¿el usuario actual es gerente?
--   supabase.rpc('is_manager')
CREATE OR REPLACE FUNCTION public.is_manager()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.staff_members
    WHERE user_id = auth.uid() AND is_active AND is_manager
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.has_view_permission(TEXT), public.is_manager() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_view_permission(TEXT), public.is_manager() TO authenticated;

-- ==============================================================================
-- 3. LECTURAS DE LA MATRIZ PARA EL GERENTE
-- ==============================================================================
-- Reportes de usuarios: quien reporta ve los suyos; userManagement y el
-- gerente (reports) ven todos. Resolverlos sigue requiriendo userManagement.
DROP POLICY IF EXISTS "Reporters see own reports, managers see all" ON public.user_reports;
CREATE POLICY "Reporters see own reports, managers see all"
  ON public.user_reports FOR SELECT
  TO authenticated
  USING (
    reporter_id = auth.uid()
    OR public.has_permission('userManagement')
    OR public.has_view_permission('reports')
  );

-- Alertas de seguridad: consulta con security (incluido el gerente).
DROP POLICY IF EXISTS "Security staff can view alerts" ON public.suspicious_activities;
CREATE POLICY "Security staff can view alerts"
  ON public.suspicious_activities FOR SELECT
  TO authenticated
  USING (public.has_view_permission('security'));

-- Auditoría sin montos de negociaciones (REQ-47), también para el gerente.
DROP POLICY IF EXISTS "Security staff can view audit without negotiation amounts" ON public.audit_log;
CREATE POLICY "Security staff can view audit without negotiation amounts"
  ON public.audit_log FOR SELECT
  TO authenticated
  USING (
    public.has_view_permission('security')
    AND NOT (
      table_name = 'negotiations'
      AND field IN ('proposed_price_per_mt', 'requested_volume_mt')
    )
  );

-- Dashboard agregado: se reemplaza solo la validación de acceso (el cálculo
-- es el de la migración 0011).
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.admin_dashboard_stats()'::regprocedure) INTO v_def;
  IF position('has_permission(''dashboard'')' IN v_def) > 0 THEN
    EXECUTE replace(v_def, 'has_permission(''dashboard'')', 'has_view_permission(''dashboard'')');
  END IF;
END $$;
