-- ==============================================================================
-- Notificaciones y alertas de envío (base de REQ-20; REQ-49, decisión D6)
-- ==============================================================================
-- * notifications: bandeja de cada usuario. Solo la base de datos crea
--   notificaciones (triggers y funciones internas); la app las lee, las marca
--   como leídas o las borra. Se publican por Realtime para recibirlas al instante.
-- * alert_preferences: el usuario apaga o enciende las alertas de clima y de
--   envío (pantalla de Configuración, REQ-43). Sin fila = todo encendido.
--   Las notificaciones de negociación siempre se entregan.
-- * Negociación: cada cambio (solicitud nueva, contraoferta, aceptación,
--   confirmación, rechazo, cancelación) avisa a la otra parte.
-- * Envío: tras confirmar el trato, el exportador avanza el estado
--   (preparando -> embarcado -> en_puerto) y el importador confirma la entrega
--   (entregado), con rpc('update_shipping_status'). Cada paso avisa a la otra
--   parte y queda en shipment_events y en la línea de tiempo (REQ-19).
-- Las alertas de clima están en la migración 20261105040000_weather_alerts.sql.
-- ==============================================================================

-- ==============================================================================
-- 1. TABLA: notifications
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('negociacion', 'envio', 'clima', 'sistema')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread
  ON public.notifications (user_id) WHERE read_at IS NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see their own notifications" ON public.notifications;
CREATE POLICY "Users see their own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users mark their own notifications as read" ON public.notifications;
CREATE POLICY "Users mark their own notifications as read"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users delete their own notifications" ON public.notifications;
CREATE POLICY "Users delete their own notifications"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- La app no crea notificaciones y solo puede cambiar read_at.
REVOKE INSERT, UPDATE, TRUNCATE ON public.notifications FROM authenticated, anon;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

-- Realtime: la app se suscribe a los INSERT de sus propias filas (aplica RLS).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- ==============================================================================
-- 2. TABLA: alert_preferences
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.alert_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  weather_alerts BOOLEAN NOT NULL DEFAULT true,
  shipping_alerts BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

DROP TRIGGER IF EXISTS set_alert_preferences_updated_at ON public.alert_preferences;
CREATE TRIGGER set_alert_preferences_updated_at
  BEFORE UPDATE ON public.alert_preferences
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.alert_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their own alert preferences" ON public.alert_preferences;
CREATE POLICY "Users manage their own alert preferences"
  ON public.alert_preferences FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ==============================================================================
-- 3. FUNCIÓN INTERNA: entregar una notificación respetando las preferencias
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.notify_user(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS BOOLEAN AS $$
DECLARE
  v_enabled BOOLEAN;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN false;
  END IF;

  IF p_type = 'clima' THEN
    SELECT weather_alerts INTO v_enabled FROM public.alert_preferences WHERE user_id = p_user_id;
  ELSIF p_type = 'envio' THEN
    SELECT shipping_alerts INTO v_enabled FROM public.alert_preferences WHERE user_id = p_user_id;
  END IF;
  IF NOT COALESCE(v_enabled, true) THEN
    RETURN false;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, COALESCE(p_data, '{}'::jsonb));
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.notify_user(UUID, TEXT, TEXT, TEXT, JSONB)
  FROM PUBLIC, authenticated, anon;

-- ==============================================================================
-- 4. AVISOS DE NEGOCIACIÓN
-- ==============================================================================
-- Se avisa a las partes que no hicieron el cambio (auth.uid()). Si el cambio
-- lo hizo el sistema (ej. rechazo por volumen insuficiente), se avisa a ambas.
CREATE OR REPLACE FUNCTION public.notify_negotiation_change()
RETURNS TRIGGER AS $$
DECLARE
  v_variety TEXT;
  v_actor UUID := auth.uid();
  v_deal TEXT;
  v_title TEXT;
  v_body TEXT;
  v_data JSONB;
  v_recipient UUID;
BEGIN
  SELECT variety INTO v_variety FROM public.offers WHERE id = NEW.offer_id;
  v_variety := COALESCE(v_variety, 'tu oferta');
  v_deal := format('%s MT a %s USD/MT', trim_scale(NEW.requested_volume_mt), trim_scale(NEW.proposed_price_per_mt));
  v_data := jsonb_build_object('negotiation_id', NEW.id, 'offer_id', NEW.offer_id, 'status', NEW.status);

  IF TG_OP = 'INSERT' THEN
    PERFORM public.notify_user(NEW.seller_id, 'negociacion', 'Nueva solicitud de compra',
      format('Recibiste una solicitud por %s: %s.', v_variety, v_deal), v_data);
    RETURN NULL;
  END IF;

  -- Contraoferta: avisa a quien le toca responder.
  IF NEW.round_count <> OLD.round_count AND NEW.status IN ('pending', 'countered') THEN
    PERFORM public.notify_user(public.negotiation_turn(NEW), 'negociacion', 'Nueva contraoferta',
      format('Ronda %s por %s: %s. Es tu turno de responder.', NEW.round_count, v_variety, v_deal), v_data);
    RETURN NULL;
  END IF;

  -- Primera confirmación del acuerdo: avisa a quien falta por confirmar.
  IF NEW.status = 'accepted' AND OLD.status = 'accepted' THEN
    IF OLD.buyer_confirmed_at IS NULL AND NEW.buyer_confirmed_at IS NOT NULL
       AND NEW.seller_confirmed_at IS NULL THEN
      PERFORM public.notify_user(NEW.seller_id, 'negociacion', 'El importador confirmó el trato',
        format('Falta tu confirmación para cerrar el trato por %s (%s).', v_variety, v_deal), v_data);
    ELSIF OLD.seller_confirmed_at IS NULL AND NEW.seller_confirmed_at IS NOT NULL
       AND NEW.buyer_confirmed_at IS NULL THEN
      PERFORM public.notify_user(NEW.buyer_id, 'negociacion', 'El exportador confirmó el trato',
        format('Falta tu confirmación para cerrar el trato por %s (%s).', v_variety, v_deal), v_data);
    END IF;
    RETURN NULL;
  END IF;

  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NULL;
  END IF;

  CASE NEW.status
    WHEN 'accepted' THEN
      v_title := 'Propuesta aceptada';
      v_body := format('Aceptaron la propuesta por %s (%s). Confirma el trato para cerrarlo.', v_variety, v_deal);
    WHEN 'confirmed' THEN
      v_title := 'Trato confirmado';
      v_body := format('El trato por %s (%s) quedó confirmado por ambas partes.', v_variety, v_deal);
    WHEN 'rejected' THEN
      v_title := 'Negociación rechazada';
      v_body := format('La negociación por %s fue rechazada', v_variety)
        || COALESCE(': ' || NEW.close_reason, '.');
    WHEN 'cancelled' THEN
      v_title := 'Negociación cancelada';
      v_body := format('La negociación por %s fue cancelada', v_variety)
        || COALESCE(': ' || NEW.close_reason, '.');
    ELSE
      RETURN NULL;
  END CASE;

  FOREACH v_recipient IN ARRAY ARRAY[NEW.buyer_id, NEW.seller_id] LOOP
    IF v_recipient IS DISTINCT FROM v_actor THEN
      PERFORM public.notify_user(v_recipient, 'negociacion', v_title, v_body, v_data);
    END IF;
  END LOOP;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.notify_negotiation_change() FROM PUBLIC, authenticated, anon;

DROP TRIGGER IF EXISTS notify_negotiation_change ON public.negotiations;
CREATE TRIGGER notify_negotiation_change
  AFTER INSERT OR UPDATE ON public.negotiations
  FOR EACH ROW EXECUTE FUNCTION public.notify_negotiation_change();

-- ==============================================================================
-- 5. ESTADO DEL ENVÍO
-- ==============================================================================
ALTER TABLE public.negotiations
  ADD COLUMN IF NOT EXISTS shipping_status TEXT,
  ADD COLUMN IF NOT EXISTS shipping_updated_at TIMESTAMPTZ;

ALTER TABLE public.negotiations DROP CONSTRAINT IF EXISTS negotiations_shipping_status_check;
ALTER TABLE public.negotiations
  ADD CONSTRAINT negotiations_shipping_status_check CHECK (
    shipping_status IS NULL
    OR (status = 'confirmed' AND shipping_status IN ('preparando', 'embarcado', 'en_puerto', 'entregado'))
  );

CREATE OR REPLACE FUNCTION public.shipping_status_label(p_status TEXT)
RETURNS TEXT AS $$
  SELECT CASE p_status
    WHEN 'preparando' THEN 'En preparación'
    WHEN 'embarcado' THEN 'Embarcado'
    WHEN 'en_puerto' THEN 'En puerto de destino'
    WHEN 'entregado' THEN 'Entregado'
  END;
$$ LANGUAGE sql IMMUTABLE SET search_path = public;

CREATE TABLE IF NOT EXISTS public.shipment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id UUID NOT NULL REFERENCES public.negotiations(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('preparando', 'embarcado', 'en_puerto', 'entregado')),
  note TEXT CHECK (note IS NULL OR char_length(note) <= 500),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_shipment_events_negotiation
  ON public.shipment_events (negotiation_id, created_at);

ALTER TABLE public.shipment_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Parties can view shipment events" ON public.shipment_events;
CREATE POLICY "Parties can view shipment events"
  ON public.shipment_events FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.negotiations n
    WHERE n.id = negotiation_id AND auth.uid() IN (n.buyer_id, n.seller_id)
  ));

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.shipment_events FROM authenticated, anon;

-- supabase.rpc('update_shipping_status', params: {'p_negotiation_id': id,
--   'p_status': 'embarcado', 'p_note': 'Contenedor MSCU1234567, Buenaventura'})
CREATE OR REPLACE FUNCTION public.update_shipping_status(
  p_negotiation_id UUID,
  p_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS public.negotiations AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE := public.lock_my_negotiation(p_negotiation_id);
  v_order CONSTANT TEXT[] := ARRAY['preparando', 'embarcado', 'en_puerto', 'entregado'];
  v_new_pos INT := array_position(v_order, p_status);
  v_old_pos INT := COALESCE(array_position(v_order, v_neg.shipping_status), 0);
  v_note TEXT := NULLIF(btrim(p_note), '');
  v_variety TEXT;
  v_recipient UUID;
BEGIN
  IF v_neg.status <> 'confirmed' THEN
    RAISE EXCEPTION 'El envío se registra solo en tratos confirmados por ambas partes.';
  END IF;
  IF v_new_pos IS NULL THEN
    RAISE EXCEPTION 'Estado de envío no válido: usa preparando, embarcado, en_puerto o entregado.';
  END IF;
  IF v_note IS NOT NULL AND char_length(v_note) > 500 THEN
    RAISE EXCEPTION 'La nota del envío no puede superar los 500 caracteres.';
  END IF;
  IF p_status = 'entregado' AND auth.uid() <> v_neg.buyer_id THEN
    RAISE EXCEPTION 'Solo el importador puede confirmar que recibió la carga.';
  END IF;
  IF p_status <> 'entregado' AND auth.uid() <> v_neg.seller_id THEN
    RAISE EXCEPTION 'Solo el exportador actualiza el envío; el importador confirma la entrega.';
  END IF;
  IF v_new_pos <= v_old_pos THEN
    RAISE EXCEPTION 'El envío ya está "%"; solo puede avanzar.', public.shipping_status_label(v_neg.shipping_status);
  END IF;
  IF p_status = 'entregado' AND v_old_pos < 2 THEN
    RAISE EXCEPTION 'No se puede confirmar la entrega de una carga que aún no ha sido embarcada.';
  END IF;

  UPDATE public.negotiations
  SET shipping_status = p_status,
      shipping_updated_at = timezone('utc'::text, now())
  WHERE id = p_negotiation_id
  RETURNING * INTO v_neg;

  INSERT INTO public.shipment_events (negotiation_id, status, note, created_by)
  VALUES (v_neg.id, p_status, v_note, auth.uid());

  SELECT variety INTO v_variety FROM public.offers WHERE id = v_neg.offer_id;
  v_recipient := CASE WHEN auth.uid() = v_neg.seller_id THEN v_neg.buyer_id ELSE v_neg.seller_id END;
  PERFORM public.notify_user(
    v_recipient, 'envio', 'Actualización de envío',
    format('%s (%s MT): %s.', COALESCE(v_variety, 'Tu trato'), trim_scale(v_neg.requested_volume_mt),
           public.shipping_status_label(p_status))
      || COALESCE(' ' || v_note, ''),
    jsonb_build_object('negotiation_id', v_neg.id, 'offer_id', v_neg.offer_id, 'shipping_status', p_status)
  );

  RETURN v_neg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.update_shipping_status(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_shipping_status(UUID, TEXT, TEXT) TO authenticated;

-- ==============================================================================
-- 6. LÍNEA DE TIEMPO (REQ-19): se agregan los pasos del envío
-- ==============================================================================
-- Mismo contenido que la migración 20261019000000_commercial_privacy.sql más
-- los eventos de shipment_events (event_type 'envio').
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

    UNION ALL

    SELECT e.created_at, 'envio'::TEXT, e.created_by, pe.name,
           'Envío: ' || public.shipping_status_label(e.status) || COALESCE(' — "' || e.note || '"', ''),
           NULL::NUMERIC, NULL::NUMERIC
    FROM public.shipment_events e
    LEFT JOIN public.profiles pe ON pe.id = e.created_by
    WHERE e.negotiation_id = p_negotiation_id
  ) t
  ORDER BY t.ev_at, CASE t.ev_type WHEN 'propuesta' THEN 0 WHEN 'aceptada' THEN 1
                                   WHEN 'confirmacion' THEN 2 WHEN 'envio' THEN 4 ELSE 3 END;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;
