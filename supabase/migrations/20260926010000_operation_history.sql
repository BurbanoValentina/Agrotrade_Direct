-- ==============================================================================
-- AgroTrade Direct — Migración 0007: Historial de operaciones
-- REQ-19: Crear historial de operaciones.
-- Base para REQ-30 (exportar historial a PDF / CSV).
--
-- * my_operation_history(): negociaciones cerradas del usuario (confirmadas,
--   rechazadas, canceladas) con los datos listos para mostrar o exportar.
-- * negotiation_timeline(): línea de tiempo de una operación (cada propuesta,
--   aceptación, confirmaciones y cierre), a partir de negotiation_rounds y
--   audit_log.
-- * Protección: no se puede eliminar una oferta con tratos confirmados (se
--   perdería el historial, porque negotiations se borra en cascada).
-- ==============================================================================

-- ==============================================================================
-- 1. ETIQUETAS EN ESPAÑOL
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.negotiation_status_label(p_status TEXT)
RETURNS TEXT AS $$
  SELECT CASE p_status
    WHEN 'pending' THEN 'Pendiente'
    WHEN 'countered' THEN 'Contraofertada'
    WHEN 'accepted' THEN 'Aceptada'
    WHEN 'confirmed' THEN 'Confirmada'
    WHEN 'rejected' THEN 'Rechazada'
    WHEN 'cancelled' THEN 'Cancelada'
    ELSE p_status
  END;
$$ LANGUAGE sql IMMUTABLE SET search_path = public;

-- ==============================================================================
-- 2. RPC: my_operation_history (REQ-19)
-- ==============================================================================
--   supabase.rpc('my_operation_history', params: {
--     'p_from': '2026-01-01', 'p_to': '2026-12-31', 'p_status': 'confirmed'})
-- Todos los parámetros son opcionales. p_all_users = true devuelve las
-- operaciones de todos (requiere el permiso negotiationManagement).
CREATE OR REPLACE FUNCTION public.my_operation_history(
  p_from TIMESTAMPTZ DEFAULT NULL,
  p_to TIMESTAMPTZ DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_all_users BOOLEAN DEFAULT false
)
RETURNS TABLE (
  negotiation_id UUID,
  offer_id UUID,
  crop_type TEXT,
  variety TEXT,
  origin_region TEXT,
  destination_country TEXT,
  my_role TEXT,              -- 'comprador' | 'vendedor' | 'admin'
  buyer_name TEXT,
  seller_name TEXT,
  counterparty_name TEXT,
  counterparty_company TEXT,
  status TEXT,
  status_label TEXT,
  price_per_mt NUMERIC,
  volume_mt NUMERIC,
  total_usd NUMERIC,
  round_count INT,
  created_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  close_reason TEXT
) AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('confirmed', 'rejected', 'cancelled') THEN
    RAISE EXCEPTION 'Estado no válido para el historial: % (usa confirmed, rejected o cancelled).', p_status;
  END IF;
  IF p_all_users AND NOT public.has_permission('negotiationManagement') THEN
    RAISE EXCEPTION 'Requiere el permiso negotiationManagement.';
  END IF;

  RETURN QUERY
  SELECT
    n.id,
    n.offer_id,
    o.crop_type,
    o.variety,
    o.origin_region,
    o.destination_country,
    CASE
      WHEN v_uid = n.buyer_id THEN 'comprador'
      WHEN v_uid = n.seller_id THEN 'vendedor'
      ELSE 'admin'
    END,
    pb.name,
    ps.name,
    CASE WHEN v_uid = n.buyer_id THEN ps.name ELSE pb.name END,
    CASE WHEN v_uid = n.buyer_id THEN ps.company_name ELSE pb.company_name END,
    n.status,
    public.negotiation_status_label(n.status),
    n.proposed_price_per_mt,
    n.requested_volume_mt,
    round(n.proposed_price_per_mt * n.requested_volume_mt, 2),
    n.round_count,
    n.created_at,
    COALESCE(n.confirmed_at, n.updated_at),
    n.close_reason
  FROM public.negotiations n
  JOIN public.offers o ON o.id = n.offer_id
  JOIN public.profiles pb ON pb.id = n.buyer_id
  JOIN public.profiles ps ON ps.id = n.seller_id
  WHERE n.status IN ('confirmed', 'rejected', 'cancelled')
    AND (p_all_users OR v_uid IN (n.buyer_id, n.seller_id))
    AND (p_status IS NULL OR n.status = p_status)
    AND (p_from IS NULL OR COALESCE(n.confirmed_at, n.updated_at) >= p_from)
    AND (p_to IS NULL OR COALESCE(n.confirmed_at, n.updated_at) <= p_to)
  ORDER BY COALESCE(n.confirmed_at, n.updated_at) DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- ==============================================================================
-- 3. RPC: negotiation_timeline (REQ-19)
-- ==============================================================================
--   supabase.rpc('negotiation_timeline', params: {'p_negotiation_id': id})
-- event_type: 'propuesta' | 'aceptada' | 'confirmacion' | 'confirmada' |
--             'rechazada' | 'cancelada'
CREATE OR REPLACE FUNCTION public.negotiation_timeline(p_negotiation_id UUID)
RETURNS TABLE (
  event_at TIMESTAMPTZ,
  event_type TEXT,
  actor_id UUID,
  actor_name TEXT,
  description TEXT,
  price_per_mt NUMERIC,
  volume_mt NUMERIC
) AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE;
BEGIN
  SELECT * INTO v_neg FROM public.negotiations WHERE id = p_negotiation_id;
  IF NOT FOUND
     OR (auth.uid() NOT IN (v_neg.buyer_id, v_neg.seller_id)
         AND NOT public.has_permission('negotiationManagement')) THEN
    RAISE EXCEPTION 'La negociación no existe o no participas en ella.';
  END IF;

  RETURN QUERY
  SELECT * FROM (
    -- Cada propuesta del ida y vuelta.
    SELECT
      r.created_at AS ev_at,
      'propuesta'::TEXT AS ev_type,
      r.proposed_by AS ev_actor,
      p.name AS ev_actor_name,
      CASE WHEN r.round_number = 1
        THEN format('Solicitud inicial: %s USD/MT por %s MT', r.price_per_mt, r.volume_mt)
        ELSE format('Ronda %s: contraoferta de %s USD/MT por %s MT', r.round_number, r.price_per_mt, r.volume_mt)
      END || COALESCE(' — "' || r.message || '"', '') AS ev_description,
      r.price_per_mt AS ev_price,
      r.volume_mt AS ev_volume
    FROM public.negotiation_rounds r
    LEFT JOIN public.profiles p ON p.id = r.proposed_by
    WHERE r.negotiation_id = p_negotiation_id

    UNION ALL

    -- Aceptación, rechazo, cancelación y cierre (auditoría de estados).
    SELECT
      a.changed_at,
      CASE a.new_value
        WHEN 'accepted' THEN 'aceptada'
        WHEN 'confirmed' THEN 'confirmada'
        WHEN 'rejected' THEN 'rechazada'
        ELSE 'cancelada'
      END,
      a.changed_by,
      p.name,
      CASE a.new_value
        WHEN 'accepted' THEN 'Propuesta aceptada; falta la confirmación de ambas partes'
        WHEN 'confirmed' THEN 'Trato confirmado por ambas partes'
        WHEN 'rejected' THEN 'Negociación rechazada'
        ELSE 'Negociación cancelada'
      END || CASE
        WHEN a.new_value IN ('rejected', 'cancelled') AND v_neg.close_reason IS NOT NULL
        THEN ': ' || v_neg.close_reason ELSE ''
      END,
      NULL::NUMERIC,
      NULL::NUMERIC
    FROM public.audit_log a
    LEFT JOIN public.profiles p ON p.id = a.changed_by
    WHERE a.table_name = 'negotiations'
      AND a.record_id = p_negotiation_id
      AND a.field = 'status'
      AND a.action = 'UPDATE'
      AND a.new_value IN ('accepted', 'confirmed', 'rejected', 'cancelled')

    UNION ALL

    -- Confirmación individual de cada parte.
    SELECT v_neg.buyer_confirmed_at, 'confirmacion'::TEXT, v_neg.buyer_id, pb.name,
           'Confirmó el trato (comprador)', NULL::NUMERIC, NULL::NUMERIC
    FROM public.profiles pb
    WHERE pb.id = v_neg.buyer_id AND v_neg.buyer_confirmed_at IS NOT NULL

    UNION ALL

    SELECT v_neg.seller_confirmed_at, 'confirmacion'::TEXT, v_neg.seller_id, ps.name,
           'Confirmó el trato (vendedor)', NULL::NUMERIC, NULL::NUMERIC
    FROM public.profiles ps
    WHERE ps.id = v_neg.seller_id AND v_neg.seller_confirmed_at IS NOT NULL
  ) t
  ORDER BY t.ev_at, CASE t.ev_type WHEN 'propuesta' THEN 0 WHEN 'aceptada' THEN 1
                                   WHEN 'confirmacion' THEN 2 ELSE 3 END;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION
  public.my_operation_history(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, BOOLEAN),
  public.negotiation_timeline(UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  public.my_operation_history(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, BOOLEAN),
  public.negotiation_timeline(UUID)
TO authenticated;

-- ==============================================================================
-- 4. PROTEGER EL HISTORIAL: ofertas con tratos confirmados no se eliminan
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.protect_offer_history()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.negotiations
    WHERE offer_id = OLD.id AND status = 'confirmed'
  ) THEN
    RAISE EXCEPTION 'No se puede eliminar una oferta con tratos confirmados: forma parte del historial de operaciones. Cámbiala a estado "cerrada".';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS protect_offer_history ON public.offers;
CREATE TRIGGER protect_offer_history
  BEFORE DELETE ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.protect_offer_history();

-- ==============================================================================
-- 5. CORRECCIÓN (migración 0004): reglas de revisión y borrados en cascada
-- ==============================================================================
-- Al eliminar una oferta, negociación o usuario, Postgres pone en NULL las
-- referencias de alertas y reportes (ON DELETE SET NULL). La regla anterior lo
-- trataba como una edición del contenido y bloqueaba el borrado. Ahora:
--   * Revisión (cambia el estado o la resolución): solo se permite cambiar
--     estado/resolución y se registra quién revisó.
--   * Sin revisión: solo se permite que referencias pasen a NULL.
CREATE OR REPLACE FUNCTION public.enforce_review_update()
RETURNS TRIGGER AS $$
DECLARE
  v_is_review BOOLEAN;
  v_content_changed BOOLEAN;
  v_ref_reassigned BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'user_reports' THEN
    v_is_review := NEW.status IS DISTINCT FROM OLD.status
                   OR NEW.resolution IS DISTINCT FROM OLD.resolution;
    v_content_changed := NEW.reporter_id IS DISTINCT FROM OLD.reporter_id
                         OR NEW.reported_user_id IS DISTINCT FROM OLD.reported_user_id
                         OR NEW.category IS DISTINCT FROM OLD.category
                         OR NEW.description IS DISTINCT FROM OLD.description
                         OR NEW.created_at IS DISTINCT FROM OLD.created_at;
    v_ref_reassigned := NEW.negotiation_id IS NOT NULL
                        AND NEW.negotiation_id IS DISTINCT FROM OLD.negotiation_id;
  ELSE
    v_is_review := NEW.status IS DISTINCT FROM OLD.status;
    v_content_changed := NEW.type IS DISTINCT FROM OLD.type
                         OR NEW.description IS DISTINCT FROM OLD.description
                         OR NEW.severity IS DISTINCT FROM OLD.severity
                         OR NEW.detected_at IS DISTINCT FROM OLD.detected_at;
    v_ref_reassigned := (NEW.related_user_id IS NOT NULL
                         AND NEW.related_user_id IS DISTINCT FROM OLD.related_user_id)
                        OR (NEW.related_offer_id IS NOT NULL
                            AND NEW.related_offer_id IS DISTINCT FROM OLD.related_offer_id);
  END IF;

  IF v_content_changed OR v_ref_reassigned THEN
    IF TG_TABLE_NAME = 'user_reports' THEN
      RAISE EXCEPTION 'Solo se puede cambiar el estado y la resolución del reporte';
    END IF;
    RAISE EXCEPTION 'Solo se puede cambiar el estado de la alerta';
  END IF;

  IF NOT v_is_review THEN
    -- Limpieza de referencias por un borrado en cascada: se deja tal cual.
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'suspicious_activities' THEN
    NEW.reviewed_at := timezone('utc'::text, now());
  END IF;
  NEW.reviewed_by := auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;
