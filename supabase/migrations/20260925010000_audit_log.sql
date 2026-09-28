-- ==============================================================================
-- AgroTrade Direct — Migración 0002: Registro de auditoría
-- REQ-32: Registro de auditoría (logs) de cambios de precio y estado.
-- Base para REQ-19 (historial de operaciones) y REQ-30 (exportar a PDF / CSV).
--
-- Cada cambio relevante en offers y negotiations queda registrado por triggers
-- con fecha, usuario y valor anterior / nuevo. Los usuarios no pueden escribir,
-- editar ni borrar registros: solo leer los que les corresponden.
-- ==============================================================================

-- ==============================================================================
-- 1. TABLA: audit_log
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.audit_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name TEXT NOT NULL CHECK (table_name IN ('offers', 'negotiations')),
  record_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  field TEXT,                 -- columna que cambió (NULL en DELETE)
  old_value TEXT,
  new_value TEXT,
  changed_by UUID,            -- auth.uid(); NULL si el cambio vino del SQL Editor / service_role
  -- Usuarios que pueden ver este registro (vendedor y comprador al momento del
  -- cambio). Se guarda aquí para que el historial siga visible aunque la oferta
  -- o la negociación se eliminen después.
  visible_to UUID[] NOT NULL DEFAULT '{}',
  changed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_audit_log_record ON public.audit_log(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON public.audit_log(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_visible_to ON public.audit_log USING GIN (visible_to);

-- ==============================================================================
-- 2. FUNCIÓN DE TRIGGER
-- ==============================================================================
-- SECURITY DEFINER: escribe en audit_log aunque el usuario no tenga permiso de
-- INSERT sobre la tabla.
CREATE OR REPLACE FUNCTION public.log_audit_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row RECORD;
  v_visible UUID[];
  v_fields TEXT[];
  v_field TEXT;
  v_old TEXT;
  v_new TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_row := OLD;
  ELSE
    v_row := NEW;
  END IF;

  IF TG_TABLE_NAME = 'offers' THEN
    v_visible := ARRAY[v_row.seller_id];
    v_fields := ARRAY['ask_price_per_mt', 'volume_mt', 'status'];
  ELSE
    v_visible := ARRAY[v_row.buyer_id, v_row.seller_id];
    v_fields := ARRAY['proposed_price_per_mt', 'requested_volume_mt', 'status'];
  END IF;

  IF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_log (table_name, record_id, action, changed_by, visible_to)
    VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', v_uid, v_visible);
    RETURN OLD;
  END IF;

  FOREACH v_field IN ARRAY v_fields LOOP
    v_new := to_jsonb(NEW) ->> v_field;
    IF TG_OP = 'INSERT' THEN
      v_old := NULL;
    ELSE
      v_old := to_jsonb(OLD) ->> v_field;
    END IF;

    IF TG_OP = 'INSERT' OR v_old IS DISTINCT FROM v_new THEN
      INSERT INTO public.audit_log
        (table_name, record_id, action, field, old_value, new_value, changed_by, visible_to)
      VALUES
        (TG_TABLE_NAME, NEW.id, TG_OP, v_field, v_old, v_new, v_uid, v_visible);
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS audit_offers ON public.offers;
CREATE TRIGGER audit_offers
  AFTER INSERT OR UPDATE OR DELETE ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_changes();

DROP TRIGGER IF EXISTS audit_negotiations ON public.negotiations;
CREATE TRIGGER audit_negotiations
  AFTER INSERT OR UPDATE OR DELETE ON public.negotiations
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_changes();

-- ==============================================================================
-- 3. SEGURIDAD
-- ==============================================================================
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Solo lectura desde la app: nadie puede alterar el registro de auditoría.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.audit_log FROM authenticated, anon;
-- La función de trigger se ejecuta sola; no se expone como RPC.
REVOKE EXECUTE ON FUNCTION public.log_audit_changes() FROM PUBLIC, authenticated, anon;

DROP POLICY IF EXISTS "Users can view their own audit entries" ON public.audit_log;
CREATE POLICY "Users can view their own audit entries"
  ON public.audit_log FOR SELECT
  TO authenticated
  USING (auth.uid() = ANY (visible_to));
-- La política de lectura total para administradores se agrega con REQ-24.
