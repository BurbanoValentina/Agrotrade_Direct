-- ==============================================================================
-- AgroTrade Direct — Migración 0014: Publicar, editar y cerrar ofertas
-- REQ-06 a REQ-10: el exportador publica ofertas (producto, precio, cantidad,
-- destino) y las administra desde la app.
--
-- Las políticas RLS de la migración base ya permiten al exportador crear y
-- editar SUS ofertas. Esta migración agrega las reglas de negocio:
--   * Una oferta nueva siempre nace 'activa'.
--   * El estado lo maneja el sistema (activa ⇄ negociando, confirmada al
--     vender todo); el exportador solo puede CERRAR su oferta ('cerrada').
--   * No se edita una oferta confirmada, en tránsito o cerrada.
--   * El volumen no puede bajar de lo comprometido en acuerdos aceptados.
--   * Al cerrar, las solicitudes en curso se cancelan con un motivo; si hay un
--     acuerdo aceptado sin confirmar, primero hay que resolverlo.
-- Las funciones internas (SECURITY DEFINER, ej. confirm_negotiation) no pasan
-- por estas reglas: se distinguen porque no corren como el rol authenticated.
-- ==============================================================================

-- ==============================================================================
-- 1. AL PUBLICAR
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.validate_offer_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF current_user <> 'authenticated' THEN
    RETURN NEW;  -- SQL Editor, seed o funciones internas
  END IF;

  NEW.status := 'activa';
  NEW.variety := trim(NEW.variety);
  NEW.origin_region := trim(NEW.origin_region);
  NEW.destination_country := trim(NEW.destination_country);

  IF length(NEW.variety) < 2 THEN
    RAISE EXCEPTION 'Escribe la variedad del producto.';
  END IF;
  IF length(NEW.origin_region) < 2 THEN
    RAISE EXCEPTION 'Escribe la región de origen.';
  END IF;
  IF length(NEW.destination_country) < 2 THEN
    RAISE EXCEPTION 'Selecciona el país de destino.';
  END IF;
  IF NEW.ask_price_per_mt IS NULL OR NEW.ask_price_per_mt <= 0 THEN
    RAISE EXCEPTION 'El precio por tonelada debe ser mayor que cero.';
  END IF;
  IF NEW.volume_mt IS NULL OR NEW.volume_mt <= 0 THEN
    RAISE EXCEPTION 'La cantidad disponible debe ser mayor que cero.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS validate_offer_insert ON public.offers;
CREATE TRIGGER validate_offer_insert
  BEFORE INSERT ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.validate_offer_insert();

-- ==============================================================================
-- 2. AL EDITAR
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.validate_offer_update()
RETURNS TRIGGER AS $$
DECLARE
  v_committed NUMERIC;
BEGIN
  IF current_user <> 'authenticated' THEN
    RETURN NEW;  -- cambios del sistema (confirmar tratos, estado automático)
  END IF;

  IF NEW.seller_id IS DISTINCT FROM OLD.seller_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'No se puede cambiar el vendedor ni la fecha de publicación.';
  END IF;

  IF OLD.status IN ('confirmada', 'enTransito', 'cerrada') THEN
    RAISE EXCEPTION 'Esta oferta ya no se puede editar (estado: %).', OLD.status;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status <> 'cerrada' THEN
    RAISE EXCEPTION 'El estado de la oferta lo maneja el sistema; solo puedes cerrarla.';
  END IF;

  IF NEW.ask_price_per_mt <= 0 THEN
    RAISE EXCEPTION 'El precio por tonelada debe ser mayor que cero.';
  END IF;

  IF NEW.volume_mt IS DISTINCT FROM OLD.volume_mt THEN
    IF NEW.volume_mt <= 0 THEN
      RAISE EXCEPTION 'La cantidad disponible debe ser mayor que cero; para retirar la oferta, ciérrala.';
    END IF;
    SELECT COALESCE(sum(requested_volume_mt), 0) INTO v_committed
    FROM public.negotiations
    WHERE offer_id = OLD.id AND status = 'accepted';
    IF NEW.volume_mt < v_committed THEN
      RAISE EXCEPTION 'No puedes bajar la cantidad a % MT: hay % MT comprometidos en acuerdos aceptados.',
        NEW.volume_mt, v_committed;
    END IF;
  END IF;

  IF NEW.status = 'cerrada' AND EXISTS (
    SELECT 1 FROM public.negotiations WHERE offer_id = OLD.id AND status = 'accepted'
  ) THEN
    RAISE EXCEPTION 'Hay un acuerdo aceptado pendiente de confirmar: confírmalo o cancélalo antes de cerrar la oferta.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS validate_offer_update ON public.offers;
CREATE TRIGGER validate_offer_update
  BEFORE UPDATE ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.validate_offer_update();

-- ==============================================================================
-- 3. AL CERRAR: se cancelan las solicitudes en curso
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.after_offer_closed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'cerrada' AND OLD.status IS DISTINCT FROM 'cerrada' THEN
    UPDATE public.negotiations
    SET status = 'cancelled',
        close_reason = 'El exportador cerró la oferta.'
    WHERE offer_id = NEW.id AND status IN ('pending', 'countered');
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.after_offer_closed() FROM PUBLIC, authenticated, anon;

DROP TRIGGER IF EXISTS after_offer_closed ON public.offers;
CREATE TRIGGER after_offer_closed
  AFTER UPDATE OF status ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.after_offer_closed();
