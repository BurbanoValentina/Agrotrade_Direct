-- ==============================================================================
-- AgroTrade Direct — Migración 0006: Flujo completo de negociación
-- REQ-15: Aceptar o rechazar solicitudes.
-- REQ-16: Negociación de precio estilo InDrive (contraofertas).
-- REQ-17: Confirmar una negociación.
--
-- Estados de negotiations:
--   pending    Le toca responder al EXPORTADOR (la última propuesta es del importador)
--   countered  Le toca responder al IMPORTADOR (la última propuesta es del exportador)
--   accepted   Hay acuerdo; falta que AMBAS partes confirmen
--   confirmed  Trato cerrado: se descuenta el volumen de la oferta
--   rejected   Rechazada por quien tenía el turno (o sin volumen disponible)
--   cancelled  Cancelada por el importador, o por cualquiera antes de confirmar
--
-- Reglas (decididas por el equipo):
--   * Máximo 10 rondas de propuesta; después solo se puede aceptar o rechazar.
--   * El trato se cierra cuando comprador Y vendedor confirman.
--   * Al confirmar, el volumen se descuenta de la oferta; si llega a 0 la oferta
--     pasa a 'confirmada' y las solicitudes activas que ya no caben se rechazan.
--
-- La app ya no actualiza negotiations directamente: cada acción es una función
-- (RPC) atómica que valida turno, rol y estado. Ver supabase/README.md.
-- ==============================================================================

-- ==============================================================================
-- 1. CAMBIOS DE ESQUEMA
-- ==============================================================================
ALTER TABLE public.negotiations DROP CONSTRAINT IF EXISTS negotiations_status_check;
ALTER TABLE public.negotiations
  ADD CONSTRAINT negotiations_status_check CHECK (status IN (
    'pending', 'countered', 'accepted', 'confirmed', 'rejected', 'cancelled'
  ));

ALTER TABLE public.negotiations
  ADD COLUMN IF NOT EXISTS round_count INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS last_proposed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS buyer_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS seller_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS close_reason TEXT;

ALTER TABLE public.negotiations DROP CONSTRAINT IF EXISTS negotiations_round_count_check;
ALTER TABLE public.negotiations
  ADD CONSTRAINT negotiations_round_count_check CHECK (round_count BETWEEN 1 AND 10);

-- Una oferta puede quedar en 0 MT solo cuando ya se vendió todo.
ALTER TABLE public.offers DROP CONSTRAINT IF EXISTS offers_volume_mt_check;
ALTER TABLE public.offers
  ADD CONSTRAINT offers_volume_mt_check CHECK (
    volume_mt > 0 OR (volume_mt = 0 AND status IN ('confirmada', 'enTransito', 'cerrada'))
  );

-- Una sola negociación viva por importador y oferta (incluye acuerdos sin confirmar).
DROP INDEX IF EXISTS public.uq_negotiations_active_request;
CREATE UNIQUE INDEX uq_negotiations_active_request
  ON public.negotiations (offer_id, buyer_id)
  WHERE status IN ('pending', 'countered', 'accepted');

-- ==============================================================================
-- 2. TABLA: negotiation_rounds (historial del ida y vuelta, REQ-16)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.negotiation_rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id UUID NOT NULL REFERENCES public.negotiations(id) ON DELETE CASCADE,
  round_number INT NOT NULL CHECK (round_number BETWEEN 1 AND 10),
  proposed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  price_per_mt NUMERIC(10, 2) NOT NULL CHECK (price_per_mt > 0),
  volume_mt NUMERIC(10, 2) NOT NULL CHECK (volume_mt > 0),
  message TEXT CHECK (message IS NULL OR length(message) <= 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE (negotiation_id, round_number)
);

CREATE INDEX IF NOT EXISTS idx_negotiation_rounds_negotiation
  ON public.negotiation_rounds(negotiation_id, round_number);

ALTER TABLE public.negotiation_rounds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Parties and managers can view rounds" ON public.negotiation_rounds;
CREATE POLICY "Parties and managers can view rounds"
  ON public.negotiation_rounds FOR SELECT
  TO authenticated
  USING (
    public.has_permission('negotiationManagement') OR
    EXISTS (
      SELECT 1 FROM public.negotiations n
      WHERE n.id = negotiation_rounds.negotiation_id
        AND auth.uid() IN (n.buyer_id, n.seller_id)
    )
  );

-- Las rondas solo las escriben las funciones de este archivo.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.negotiation_rounds FROM authenticated, anon;

-- ==============================================================================
-- 3. SOLO RPC: se quitan las actualizaciones directas desde la app
-- ==============================================================================
DROP POLICY IF EXISTS "Parties involved can update negotiations" ON public.negotiations;
REVOKE UPDATE ON public.negotiations FROM authenticated, anon;
DROP TRIGGER IF EXISTS enforce_negotiation_update ON public.negotiations;
DROP FUNCTION IF EXISTS public.enforce_negotiation_update();

-- ==============================================================================
-- 4. ESTADO AUTOMÁTICO DE LA OFERTA
-- ==============================================================================
-- activa <-> negociando según haya negociaciones vivas. No toca ofertas
-- confirmadas / en tránsito / cerradas.
CREATE OR REPLACE FUNCTION public.refresh_offer_status(p_offer_id UUID)
RETURNS VOID AS $$
DECLARE
  v_has_live BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.negotiations
    WHERE offer_id = p_offer_id AND status IN ('pending', 'countered', 'accepted')
  ) INTO v_has_live;

  UPDATE public.offers
  SET status = CASE WHEN v_has_live THEN 'negociando' ELSE 'activa' END
  WHERE id = p_offer_id
    AND status IN ('activa', 'negociando')
    AND status <> CASE WHEN v_has_live THEN 'negociando' ELSE 'activa' END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.refresh_offer_status(UUID) FROM PUBLIC, authenticated, anon;

-- ==============================================================================
-- 5. SOLICITUD NUEVA: reglas de REQ-14 + ronda 1
-- ==============================================================================
-- Se redefine para contar 'accepted' como negociación viva y dejar registrado
-- quién hizo la primera propuesta.
CREATE OR REPLACE FUNCTION public.validate_purchase_request()
RETURNS TRIGGER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_offer public.offers%ROWTYPE;
  v_role TEXT;
BEGIN
  SELECT * INTO v_offer FROM public.offers WHERE id = NEW.offer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'La oferta no existe o fue eliminada.';
  END IF;

  NEW.seller_id := v_offer.seller_id;
  NEW.requested_volume_mt := COALESCE(NEW.requested_volume_mt, v_offer.volume_mt);
  NEW.round_count := 1;
  NEW.last_proposed_by := NEW.buyer_id;

  IF v_uid IS NULL THEN
    RETURN NEW;
  END IF;

  NEW.status := 'pending';
  NEW.accepted_at := NULL;
  NEW.buyer_confirmed_at := NULL;
  NEW.seller_confirmed_at := NULL;
  NEW.confirmed_at := NULL;
  NEW.close_reason := NULL;

  IF NEW.buyer_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Solo puedes enviar solicitudes a tu propio nombre.';
  END IF;

  IF public.is_blocked() THEN
    RAISE EXCEPTION 'Tu cuenta está bloqueada. No puedes enviar solicitudes de compra.';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'importador' THEN
    RAISE EXCEPTION 'Solo los importadores pueden enviar solicitudes de compra.';
  END IF;

  IF v_offer.status NOT IN ('activa', 'negociando') THEN
    RAISE EXCEPTION 'Esta oferta ya no recibe solicitudes (estado: %).', v_offer.status;
  END IF;

  IF NEW.proposed_price_per_mt IS NULL OR NEW.proposed_price_per_mt <= 0 THEN
    RAISE EXCEPTION 'El precio propuesto debe ser mayor que cero.';
  END IF;

  IF NEW.requested_volume_mt <= 0 THEN
    RAISE EXCEPTION 'El volumen solicitado debe ser mayor que cero.';
  END IF;

  IF NEW.requested_volume_mt > v_offer.volume_mt THEN
    RAISE EXCEPTION 'El volumen solicitado (% MT) supera el disponible (% MT).',
      NEW.requested_volume_mt, v_offer.volume_mt;
  END IF;

  IF NEW.notes IS NOT NULL AND length(NEW.notes) > 500 THEN
    RAISE EXCEPTION 'Las notas no pueden superar los 500 caracteres.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.negotiations
    WHERE offer_id = NEW.offer_id
      AND buyer_id = NEW.buyer_id
      AND status IN ('pending', 'countered', 'accepted')
  ) THEN
    RAISE EXCEPTION 'Ya tienes una solicitud activa para esta oferta.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.after_purchase_request()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.negotiation_rounds
    (negotiation_id, round_number, proposed_by, price_per_mt, volume_mt, message)
  VALUES
    (NEW.id, 1, NEW.buyer_id, NEW.proposed_price_per_mt, NEW.requested_volume_mt, NEW.notes);

  PERFORM public.refresh_offer_status(NEW.offer_id);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.after_purchase_request() FROM PUBLIC, authenticated, anon;

DROP TRIGGER IF EXISTS after_purchase_request ON public.negotiations;
CREATE TRIGGER after_purchase_request
  AFTER INSERT ON public.negotiations
  FOR EACH ROW EXECUTE FUNCTION public.after_purchase_request();

-- ==============================================================================
-- 6. FUNCIÓN INTERNA: cargar y bloquear la negociación del usuario
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.lock_my_negotiation(p_negotiation_id UUID)
RETURNS public.negotiations AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  SELECT * INTO v_neg FROM public.negotiations WHERE id = p_negotiation_id FOR UPDATE;
  IF NOT FOUND OR auth.uid() NOT IN (v_neg.buyer_id, v_neg.seller_id) THEN
    RAISE EXCEPTION 'La negociación no existe o no participas en ella.';
  END IF;

  IF public.is_blocked() THEN
    RAISE EXCEPTION 'Tu cuenta está bloqueada. No puedes negociar.';
  END IF;

  RETURN v_neg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.lock_my_negotiation(UUID) FROM PUBLIC, authenticated, anon;

-- A quién le toca responder: pending -> vendedor, countered -> comprador.
CREATE OR REPLACE FUNCTION public.negotiation_turn(p_neg public.negotiations)
RETURNS UUID AS $$
  SELECT CASE p_neg.status
    WHEN 'pending' THEN p_neg.seller_id
    WHEN 'countered' THEN p_neg.buyer_id
  END;
$$ LANGUAGE sql IMMUTABLE SET search_path = public;

-- ==============================================================================
-- 7. RPC: contraoferta (REQ-16)
-- ==============================================================================
--   supabase.rpc('counter_offer', params: {'p_negotiation_id': id,
--     'p_price_per_mt': 7900, 'p_volume_mt': 10, 'p_message': '...'})
CREATE OR REPLACE FUNCTION public.counter_offer(
  p_negotiation_id UUID,
  p_price_per_mt NUMERIC,
  p_volume_mt NUMERIC DEFAULT NULL,
  p_message TEXT DEFAULT NULL
)
RETURNS public.negotiations AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE := public.lock_my_negotiation(p_negotiation_id);
  v_available NUMERIC;
  v_volume NUMERIC := COALESCE(p_volume_mt, v_neg.requested_volume_mt);
BEGIN
  IF v_neg.status NOT IN ('pending', 'countered') THEN
    RAISE EXCEPTION 'Esta negociación ya no admite contraofertas (estado: %).', v_neg.status;
  END IF;
  IF public.negotiation_turn(v_neg) <> auth.uid() THEN
    RAISE EXCEPTION 'No es tu turno: espera la respuesta de la otra parte.';
  END IF;
  IF v_neg.round_count >= 10 THEN
    RAISE EXCEPTION 'Se alcanzó el límite de 10 rondas: solo puedes aceptar o rechazar.';
  END IF;
  IF p_price_per_mt IS NULL OR p_price_per_mt <= 0 THEN
    RAISE EXCEPTION 'El precio propuesto debe ser mayor que cero.';
  END IF;
  IF v_volume <= 0 THEN
    RAISE EXCEPTION 'El volumen debe ser mayor que cero.';
  END IF;
  SELECT volume_mt INTO v_available FROM public.offers WHERE id = v_neg.offer_id;
  IF v_volume > v_available THEN
    RAISE EXCEPTION 'El volumen (% MT) supera el disponible (% MT).', v_volume, v_available;
  END IF;
  IF p_message IS NOT NULL AND length(p_message) > 500 THEN
    RAISE EXCEPTION 'El mensaje no puede superar los 500 caracteres.';
  END IF;

  UPDATE public.negotiations
  SET proposed_price_per_mt = p_price_per_mt,
      requested_volume_mt = v_volume,
      round_count = round_count + 1,
      last_proposed_by = auth.uid(),
      status = CASE WHEN auth.uid() = seller_id THEN 'countered' ELSE 'pending' END
  WHERE id = p_negotiation_id
  RETURNING * INTO v_neg;

  INSERT INTO public.negotiation_rounds
    (negotiation_id, round_number, proposed_by, price_per_mt, volume_mt, message)
  VALUES
    (v_neg.id, v_neg.round_count, auth.uid(), p_price_per_mt, v_volume, NULLIF(trim(p_message), ''));

  RETURN v_neg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ==============================================================================
-- 8. RPC: aceptar la propuesta vigente (REQ-15)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.accept_negotiation(p_negotiation_id UUID)
RETURNS public.negotiations AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE := public.lock_my_negotiation(p_negotiation_id);
  v_available NUMERIC;
BEGIN
  IF v_neg.status NOT IN ('pending', 'countered') THEN
    RAISE EXCEPTION 'Esta negociación no está esperando respuesta (estado: %).', v_neg.status;
  END IF;
  IF public.negotiation_turn(v_neg) <> auth.uid() THEN
    RAISE EXCEPTION 'No es tu turno: no puedes aceptar tu propia propuesta.';
  END IF;
  SELECT volume_mt INTO v_available FROM public.offers WHERE id = v_neg.offer_id;
  IF v_neg.requested_volume_mt > v_available THEN
    RAISE EXCEPTION 'El volumen (% MT) ya no está disponible (quedan % MT).',
      v_neg.requested_volume_mt, v_available;
  END IF;

  UPDATE public.negotiations
  SET status = 'accepted', accepted_at = timezone('utc'::text, now())
  WHERE id = p_negotiation_id
  RETURNING * INTO v_neg;

  RETURN v_neg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ==============================================================================
-- 9. RPC: rechazar la propuesta vigente (REQ-15)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.reject_negotiation(p_negotiation_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS public.negotiations AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE := public.lock_my_negotiation(p_negotiation_id);
BEGIN
  IF v_neg.status NOT IN ('pending', 'countered') THEN
    RAISE EXCEPTION 'Esta negociación no está esperando respuesta (estado: %).', v_neg.status;
  END IF;
  IF public.negotiation_turn(v_neg) <> auth.uid() THEN
    RAISE EXCEPTION 'No es tu turno: espera la respuesta de la otra parte.';
  END IF;
  IF p_reason IS NOT NULL AND length(p_reason) > 500 THEN
    RAISE EXCEPTION 'El motivo no puede superar los 500 caracteres.';
  END IF;

  UPDATE public.negotiations
  SET status = 'rejected', close_reason = NULLIF(trim(p_reason), '')
  WHERE id = p_negotiation_id
  RETURNING * INTO v_neg;

  PERFORM public.refresh_offer_status(v_neg.offer_id);
  RETURN v_neg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ==============================================================================
-- 10. RPC: cancelar
-- ==============================================================================
-- El importador puede retirar su solicitud mientras se negocia; cualquiera de
-- las dos partes puede echarse atrás después de aceptar y antes de confirmar.
CREATE OR REPLACE FUNCTION public.cancel_negotiation(p_negotiation_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS public.negotiations AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE := public.lock_my_negotiation(p_negotiation_id);
BEGIN
  IF v_neg.status IN ('pending', 'countered') THEN
    IF auth.uid() <> v_neg.buyer_id THEN
      RAISE EXCEPTION 'Solo el importador puede cancelar una solicitud en curso; el exportador puede rechazarla en su turno.';
    END IF;
  ELSIF v_neg.status <> 'accepted' THEN
    RAISE EXCEPTION 'Esta negociación ya está cerrada (estado: %).', v_neg.status;
  END IF;
  IF p_reason IS NOT NULL AND length(p_reason) > 500 THEN
    RAISE EXCEPTION 'El motivo no puede superar los 500 caracteres.';
  END IF;

  UPDATE public.negotiations
  SET status = 'cancelled', close_reason = NULLIF(trim(p_reason), '')
  WHERE id = p_negotiation_id
  RETURNING * INTO v_neg;

  PERFORM public.refresh_offer_status(v_neg.offer_id);
  RETURN v_neg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ==============================================================================
-- 11. RPC: confirmar el trato (REQ-17)
-- ==============================================================================
-- Cada parte confirma una vez. Con la segunda confirmación el trato se cierra:
-- se descuenta el volumen, se suman los tratos completados y se rechazan las
-- solicitudes activas de la oferta que ya no caben en el volumen restante.
CREATE OR REPLACE FUNCTION public.confirm_negotiation(p_negotiation_id UUID)
RETURNS public.negotiations AS $$
DECLARE
  v_neg public.negotiations%ROWTYPE := public.lock_my_negotiation(p_negotiation_id);
  v_offer public.offers%ROWTYPE;
  v_now TIMESTAMPTZ := timezone('utc'::text, now());
  v_remaining NUMERIC;
BEGIN
  IF v_neg.status <> 'accepted' THEN
    RAISE EXCEPTION 'Solo se puede confirmar un acuerdo aceptado (estado: %).', v_neg.status;
  END IF;
  IF (auth.uid() = v_neg.buyer_id AND v_neg.buyer_confirmed_at IS NOT NULL)
     OR (auth.uid() = v_neg.seller_id AND v_neg.seller_confirmed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Ya confirmaste este trato; falta la confirmación de la otra parte.';
  END IF;

  UPDATE public.negotiations
  SET buyer_confirmed_at = CASE WHEN auth.uid() = buyer_id THEN v_now ELSE buyer_confirmed_at END,
      seller_confirmed_at = CASE WHEN auth.uid() = seller_id THEN v_now ELSE seller_confirmed_at END
  WHERE id = p_negotiation_id
  RETURNING * INTO v_neg;

  -- Falta la otra parte: se queda en 'accepted'.
  IF v_neg.buyer_confirmed_at IS NULL OR v_neg.seller_confirmed_at IS NULL THEN
    RETURN v_neg;
  END IF;

  -- Segunda confirmación: se cierra el trato.
  SELECT * INTO v_offer FROM public.offers WHERE id = v_neg.offer_id FOR UPDATE;
  IF v_neg.requested_volume_mt > v_offer.volume_mt THEN
    RAISE EXCEPTION 'El volumen (% MT) ya no está disponible (quedan % MT). Cancela y negocia de nuevo.',
      v_neg.requested_volume_mt, v_offer.volume_mt;
  END IF;

  v_remaining := v_offer.volume_mt - v_neg.requested_volume_mt;

  UPDATE public.negotiations
  SET status = 'confirmed', confirmed_at = v_now
  WHERE id = p_negotiation_id
  RETURNING * INTO v_neg;

  UPDATE public.offers
  SET volume_mt = v_remaining,
      status = CASE WHEN v_remaining = 0 THEN 'confirmada' ELSE status END
  WHERE id = v_offer.id;

  UPDATE public.profiles
  SET completed_trades = completed_trades + 1
  WHERE id IN (v_neg.buyer_id, v_neg.seller_id);

  UPDATE public.negotiations
  SET status = 'rejected',
      close_reason = format('Volumen insuficiente: la oferta quedó con %s MT tras otro trato confirmado.', v_remaining)
  WHERE offer_id = v_offer.id
    AND id <> v_neg.id
    AND status IN ('pending', 'countered', 'accepted')
    AND requested_volume_mt > v_remaining;

  PERFORM public.refresh_offer_status(v_offer.id);
  RETURN v_neg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION
  public.counter_offer(UUID, NUMERIC, NUMERIC, TEXT),
  public.accept_negotiation(UUID),
  public.reject_negotiation(UUID, TEXT),
  public.cancel_negotiation(UUID, TEXT),
  public.confirm_negotiation(UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  public.counter_offer(UUID, NUMERIC, NUMERIC, TEXT),
  public.accept_negotiation(UUID),
  public.reject_negotiation(UUID, TEXT),
  public.cancel_negotiation(UUID, TEXT),
  public.confirm_negotiation(UUID)
TO authenticated;

-- ==============================================================================
-- 12. AJUSTES A MIGRACIONES ANTERIORES
-- ==============================================================================
-- Calificaciones: solo sobre tratos confirmados (antes: aceptados).
DROP POLICY IF EXISTS "Parties of an accepted deal can rate each other" ON public.ratings;
DROP POLICY IF EXISTS "Parties of a confirmed deal can rate each other" ON public.ratings;
CREATE POLICY "Parties of a confirmed deal can rate each other"
  ON public.ratings FOR INSERT
  TO authenticated
  WITH CHECK (
    rater_id = auth.uid() AND
    NOT public.is_blocked() AND
    EXISTS (
      SELECT 1 FROM public.negotiations n
      WHERE n.id = ratings.negotiation_id
        AND n.status = 'confirmed'
        AND (
          (n.buyer_id = auth.uid() AND n.seller_id = ratings.rated_id) OR
          (n.seller_id = auth.uid() AND n.buyer_id = ratings.rated_id)
        )
    )
  );

-- Dashboard: negociaciones vivas incluyen acuerdos sin confirmar; el volumen y
-- valor negociado cuentan solo tratos confirmados.
CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS JSON AS $$
BEGIN
  IF NOT public.has_permission('dashboard') THEN
    RAISE EXCEPTION 'Requiere el permiso dashboard';
  END IF;

  RETURN json_build_object(
    'totalUsers', (SELECT count(*) FROM public.profiles WHERE role IN ('exportador', 'importador')),
    'activeOffers', (SELECT count(*) FROM public.offers WHERE status IN ('activa', 'negociando')),
    'activeNegotiations', (SELECT count(*) FROM public.negotiations WHERE status IN ('pending', 'countered', 'accepted')),
    'blockedUsers', (SELECT count(*) FROM public.blocked_users),
    'pendingAlerts', (SELECT count(*) FROM public.suspicious_activities WHERE status = 'pendiente'),
    'totalVolumeMt', (SELECT COALESCE(sum(requested_volume_mt), 0) FROM public.negotiations WHERE status = 'confirmed'),
    'totalValueUsd', (SELECT COALESCE(sum(requested_volume_mt * proposed_price_per_mt), 0) FROM public.negotiations WHERE status = 'confirmed')
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;
