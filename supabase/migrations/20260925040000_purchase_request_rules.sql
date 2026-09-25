-- ==============================================================================
-- AgroTrade Direct — Migración 0005: Reglas de la solicitud de compra
-- REQ-14: Permitir al importador enviar una solicitud.
--
-- Valida cada solicitud nueva con mensajes claros (la app los muestra tal cual):
--   * solo importadores no bloqueados, sobre ofertas abiertas;
--   * el volumen pedido no puede superar el disponible;
--   * una sola solicitud activa por importador y oferta;
--   * notas de máximo 500 caracteres.
-- Además completa seller_id y el volumen (si no se envía) a partir de la oferta,
-- así la app solo manda offer_id, buyer_id, precio y, opcionalmente, volumen y
-- notas. Las políticas RLS siguen activas como segunda barrera.
-- ==============================================================================

-- ==============================================================================
-- 1. RESTRICCIONES
-- ==============================================================================
ALTER TABLE public.negotiations DROP CONSTRAINT IF EXISTS negotiations_notes_length;
ALTER TABLE public.negotiations
  ADD CONSTRAINT negotiations_notes_length CHECK (notes IS NULL OR length(notes) <= 500);

-- Garantía final contra solicitudes duplicadas (incluso con envíos simultáneos).
CREATE UNIQUE INDEX IF NOT EXISTS uq_negotiations_active_request
  ON public.negotiations (offer_id, buyer_id)
  WHERE status IN ('pending', 'countered');

-- ==============================================================================
-- 2. TRIGGER DE VALIDACIÓN
-- ==============================================================================
-- Se ejecuta antes de las políticas RLS, por eso puede dar el motivo exacto del
-- rechazo en lugar del genérico "violates row-level security policy".
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

  -- Datos que salen de la oferta, no del cliente.
  NEW.seller_id := v_offer.seller_id;
  NEW.requested_volume_mt := COALESCE(NEW.requested_volume_mt, v_offer.volume_mt);

  -- Las operaciones sin usuario (SQL Editor / service_role) no se validan.
  IF v_uid IS NULL THEN
    RETURN NEW;
  END IF;

  NEW.status := 'pending';

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
      AND status IN ('pending', 'countered')
  ) THEN
    RAISE EXCEPTION 'Ya tienes una solicitud activa para esta oferta.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.validate_purchase_request() FROM PUBLIC, authenticated, anon;

DROP TRIGGER IF EXISTS validate_purchase_request ON public.negotiations;
CREATE TRIGGER validate_purchase_request
  BEFORE INSERT ON public.negotiations
  FOR EACH ROW EXECUTE FUNCTION public.validate_purchase_request();
