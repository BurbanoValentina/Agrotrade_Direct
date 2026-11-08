-- ==============================================================================
-- AgroTrade Direct — Migración 0010: Privacidad comercial
-- REQ-47 (corrección de la profesora): ningún rol, ni siquiera el super admin,
-- ve el precio o los términos de una negociación individual. Solo las dos
-- partes de la negociación los ven; el personal ve agregados y actividad sin
-- montos.
--
-- Decisiones (documento de reparto v2):
--   D1: negotiationManagement queda solo para estadísticas agregadas.
--   D2: la auditoría se muestra al personal SIN montos de negociaciones
--       (estados, quién y cuándo sí).
--
-- El precio PUBLICADO de una oferta sigue siendo público (lo muestra el
-- Market): la privacidad aplica a lo que se negocia.
-- ==============================================================================

-- ==============================================================================
-- 1. negotiations: solo las partes
-- ==============================================================================
-- La política "Parties involved can view negotiations" (migración base) sigue
-- vigente; se retira el acceso del personal.
DROP POLICY IF EXISTS "Negotiation managers can view all negotiations" ON public.negotiations;

-- ==============================================================================
-- 2. negotiation_rounds (propuestas y mensajes): solo las partes
-- ==============================================================================
DROP POLICY IF EXISTS "Parties and managers can view rounds" ON public.negotiation_rounds;
DROP POLICY IF EXISTS "Parties can view rounds" ON public.negotiation_rounds;
CREATE POLICY "Parties can view rounds"
  ON public.negotiation_rounds FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.negotiations n
      WHERE n.id = negotiation_rounds.negotiation_id
        AND auth.uid() IN (n.buyer_id, n.seller_id)
    )
  );

-- ==============================================================================
-- 3. my_operation_history: se elimina la consulta de "todos los usuarios"
-- ==============================================================================
DROP FUNCTION IF EXISTS public.my_operation_history(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION public.my_operation_history(
  p_from TIMESTAMPTZ DEFAULT NULL,
  p_to TIMESTAMPTZ DEFAULT NULL,
  p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
  negotiation_id UUID,
  offer_id UUID,
  crop_type TEXT,
  variety TEXT,
  origin_region TEXT,
  destination_country TEXT,
  my_role TEXT,              -- 'comprador' | 'vendedor'
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

  RETURN QUERY
  SELECT
    n.id,
    n.offer_id,
    o.crop_type,
    o.variety,
    o.origin_region,
    o.destination_country,
    CASE WHEN v_uid = n.buyer_id THEN 'comprador' ELSE 'vendedor' END,
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
    AND v_uid IN (n.buyer_id, n.seller_id)
    AND (p_status IS NULL OR n.status = p_status)
    AND (p_from IS NULL OR COALESCE(n.confirmed_at, n.updated_at) >= p_from)
    AND (p_to IS NULL OR COALESCE(n.confirmed_at, n.updated_at) <= p_to)
  ORDER BY COALESCE(n.confirmed_at, n.updated_at) DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.my_operation_history(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_operation_history(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;

-- ==============================================================================
-- 4. negotiation_timeline: solo las partes
-- ==============================================================================
-- Se reemplaza solo la validación de acceso; el contenido es el de la
-- migración 0007.
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
  IF NOT FOUND OR auth.uid() IS NULL OR auth.uid() NOT IN (v_neg.buyer_id, v_neg.seller_id) THEN
    RAISE EXCEPTION 'La negociación no existe o no participas en ella.';
  END IF;

  RETURN QUERY
  SELECT * FROM (
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

-- ==============================================================================
-- 5. audit_log: el personal ve la actividad, no los montos negociados (D2)
-- ==============================================================================
-- Las partes siguen viendo sus propios registros completos (política
-- "Users can view their own audit entries", migración 0002). El personal con
-- permiso security ve todo EXCEPTO el precio y el volumen de negociaciones
-- ajenas: los cambios de estado, quién y cuándo siguen visibles.
DROP POLICY IF EXISTS "Security staff can view the full audit log" ON public.audit_log;
DROP POLICY IF EXISTS "Security staff can view audit without negotiation amounts" ON public.audit_log;
CREATE POLICY "Security staff can view audit without negotiation amounts"
  ON public.audit_log FOR SELECT
  TO authenticated
  USING (
    public.has_permission('security')
    AND NOT (
      table_name = 'negotiations'
      AND field IN ('proposed_price_per_mt', 'requested_volume_mt')
    )
  );
