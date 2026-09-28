-- ==============================================================================
-- AgroTrade Direct — Migración 0009: Advertencias a usuarios
-- REQ-33: Panel de administrador para gestionar usuarios reportados
-- ("advertir o suspender una cuenta").
--
-- * user_warnings: advertencias emitidas por admins con userManagement.
-- * warn_user(): advierte; si el reporte viene de user_reports lo marca como
--   "accionTomada". Al acumular 3 advertencias la cuenta se suspende sola
--   (fila en blocked_users; un admin la puede desbloquear).
-- * acknowledge_warning(): el usuario marca una advertencia como leída.
--
-- La creación de empleados y el borrado de cuentas van en la Edge Function
-- supabase/functions/admin-users (necesitan la clave service_role).
-- ==============================================================================

-- ==============================================================================
-- 1. TABLA: user_warnings
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.user_warnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (length(trim(reason)) BETWEEN 5 AND 500),
  report_id UUID REFERENCES public.user_reports(id) ON DELETE SET NULL,
  issued_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  acknowledged_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_user_warnings_user ON public.user_warnings(user_id, created_at DESC);

ALTER TABLE public.user_warnings ENABLE ROW LEVEL SECURITY;

-- Solo lectura desde la app; las escrituras van por las RPC de abajo.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.user_warnings FROM authenticated, anon;

DROP POLICY IF EXISTS "Users see own warnings, managers see all" ON public.user_warnings;
CREATE POLICY "Users see own warnings, managers see all"
  ON public.user_warnings FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.has_permission('userManagement'));

-- ==============================================================================
-- 2. RPC: warn_user (admin con userManagement)
-- ==============================================================================
--   supabase.rpc('warn_user', params: {'p_user_id': id, 'p_reason': '...',
--                                      'p_report_id': reportId})
-- Devuelve JSON: {warning_id, warnings_count, auto_blocked}.
CREATE OR REPLACE FUNCTION public.warn_user(
  p_user_id UUID,
  p_reason TEXT,
  p_report_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_role TEXT;
  v_warning_id UUID;
  v_count INT;
  v_auto_blocked BOOLEAN := false;
  c_max_warnings CONSTANT INT := 3;
BEGIN
  IF NOT public.has_permission('userManagement') THEN
    RAISE EXCEPTION 'Requiere el permiso userManagement.';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes advertirte a ti mismo.';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El usuario no existe.';
  END IF;
  IF v_role = 'staff' THEN
    RAISE EXCEPTION 'Las advertencias son para exportadores e importadores, no para el personal.';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'Escribe el motivo de la advertencia (mínimo 5 caracteres).';
  END IF;
  IF p_report_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.user_reports WHERE id = p_report_id AND reported_user_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'El reporte indicado no corresponde a este usuario.';
  END IF;

  INSERT INTO public.user_warnings (user_id, reason, report_id, issued_by)
  VALUES (p_user_id, trim(p_reason), p_report_id, auth.uid())
  RETURNING id INTO v_warning_id;

  -- El reporte que originó la advertencia queda resuelto.
  IF p_report_id IS NOT NULL THEN
    UPDATE public.user_reports
    SET status = 'accionTomada',
        resolution = 'Advertencia enviada: ' || trim(p_reason)
    WHERE id = p_report_id AND status IN ('pendiente', 'revisada');
  END IF;

  SELECT count(*) INTO v_count FROM public.user_warnings WHERE user_id = p_user_id;

  -- Suspensión automática al llegar al límite (decisión del equipo: 3).
  IF v_count >= c_max_warnings
     AND NOT EXISTS (SELECT 1 FROM public.blocked_users WHERE user_id = p_user_id) THEN
    INSERT INTO public.blocked_users (user_id, reason, blocked_by)
    VALUES (
      p_user_id,
      format('Suspensión automática: %s advertencias. Última: %s', v_count, trim(p_reason)),
      auth.uid()
    );
    v_auto_blocked := true;
  END IF;

  RETURN json_build_object(
    'warning_id', v_warning_id,
    'warnings_count', v_count,
    'auto_blocked', v_auto_blocked
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ==============================================================================
-- 3. RPC: acknowledge_warning (el usuario advertido)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.acknowledge_warning(p_warning_id UUID)
RETURNS public.user_warnings AS $$
DECLARE
  v_warning public.user_warnings%ROWTYPE;
BEGIN
  UPDATE public.user_warnings
  SET acknowledged_at = COALESCE(acknowledged_at, timezone('utc'::text, now()))
  WHERE id = p_warning_id AND user_id = auth.uid()
  RETURNING * INTO v_warning;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La advertencia no existe.';
  END IF;
  RETURN v_warning;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION
  public.warn_user(UUID, TEXT, UUID),
  public.acknowledge_warning(UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  public.warn_user(UUID, TEXT, UUID),
  public.acknowledge_warning(UUID)
TO authenticated;
