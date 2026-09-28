-- ==============================================================================
-- AgroTrade Direct — Migración 0008: Verificación de certificaciones
-- REQ-36: el exportador adjunta el PDF de una certificación (UTZ, Rainforest
-- Alliance, etc.) y, una vez verificada por un admin, se muestra como
-- "verificada" en sus ofertas.
--
-- * Bucket privado `certifications` (solo PDF, máx. 5 MB). Cada exportador sube
--   a su carpeta `<su_id>/...`. El PDF solo lo abren su dueño y los admins con
--   permiso offerManagement (decisión del equipo).
-- * Tabla `certifications`: pending → verified / rejected (revisión con la RPC
--   review_certification). Pertenece al exportador, no a una oferta.
-- * Campo calculado `verified_certifications` en offers: certificaciones de la
--   oferta que el vendedor tiene verificadas y vigentes.
-- ==============================================================================

-- ==============================================================================
-- 1. BUCKET DE STORAGE
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('certifications', 'certifications', false, 5242880, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ==============================================================================
-- 2. TABLA: certifications
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.certifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 2 AND 80),
  certificate_number TEXT CHECK (certificate_number IS NULL OR length(certificate_number) <= 80),
  valid_until DATE,
  file_path TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
  rejection_reason TEXT CHECK (rejection_reason IS NULL OR length(rejection_reason) <= 500),
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_certifications_seller ON public.certifications(seller_id);
CREATE INDEX IF NOT EXISTS idx_certifications_status ON public.certifications(status);

DROP TRIGGER IF EXISTS set_certifications_updated_at ON public.certifications;
CREATE TRIGGER set_certifications_updated_at
  BEFORE UPDATE ON public.certifications
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ==============================================================================
-- 3. REGLAS AL REGISTRAR UN CERTIFICADO
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.validate_certification()
RETURNS TRIGGER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NEW;
  END IF;

  NEW.status := 'pending';
  NEW.rejection_reason := NULL;
  NEW.reviewed_by := NULL;
  NEW.reviewed_at := NULL;
  NEW.name := trim(NEW.name);

  IF NEW.seller_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Solo puedes registrar certificados a tu propio nombre.';
  END IF;
  IF public.is_blocked() THEN
    RAISE EXCEPTION 'Tu cuenta está bloqueada. No puedes subir certificados.';
  END IF;
  SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'exportador' THEN
    RAISE EXCEPTION 'Solo los exportadores pueden subir certificados.';
  END IF;
  IF NEW.valid_until IS NOT NULL AND NEW.valid_until < current_date THEN
    RAISE EXCEPTION 'La certificación ya está vencida (%).', NEW.valid_until;
  END IF;
  IF NEW.file_path NOT LIKE v_uid::text || '/%' OR lower(NEW.file_path) NOT LIKE '%.pdf' THEN
    RAISE EXCEPTION 'Ruta de archivo no válida: el PDF debe estar en tu carpeta del bucket certifications.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM storage.objects
    WHERE bucket_id = 'certifications' AND name = NEW.file_path
  ) THEN
    RAISE EXCEPTION 'No se encontró el PDF subido. Súbelo de nuevo.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.validate_certification() FROM PUBLIC, authenticated, anon;

DROP TRIGGER IF EXISTS validate_certification ON public.certifications;
CREATE TRIGGER validate_certification
  BEFORE INSERT ON public.certifications
  FOR EACH ROW EXECUTE FUNCTION public.validate_certification();

-- ==============================================================================
-- 4. RPC: review_certification (admin con offerManagement)
-- ==============================================================================
--   supabase.rpc('review_certification', params: {
--     'p_certification_id': id, 'p_approve': true, 'p_reason': null})
-- Aprobar: pending → verified. Rechazar (motivo obligatorio): pending o
-- verified → rejected (así un admin también puede revocar una verificación).
CREATE OR REPLACE FUNCTION public.review_certification(
  p_certification_id UUID,
  p_approve BOOLEAN,
  p_reason TEXT DEFAULT NULL
)
RETURNS public.certifications AS $$
DECLARE
  v_cert public.certifications%ROWTYPE;
BEGIN
  IF NOT public.has_permission('offerManagement') THEN
    RAISE EXCEPTION 'Requiere el permiso offerManagement.';
  END IF;

  SELECT * INTO v_cert FROM public.certifications WHERE id = p_certification_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El certificado no existe.';
  END IF;

  IF p_approve THEN
    IF v_cert.status <> 'pending' THEN
      RAISE EXCEPTION 'Solo se puede aprobar un certificado pendiente (estado: %).', v_cert.status;
    END IF;
    IF v_cert.valid_until IS NOT NULL AND v_cert.valid_until < current_date THEN
      RAISE EXCEPTION 'No se puede aprobar: la certificación venció el %.', v_cert.valid_until;
    END IF;
  ELSE
    IF v_cert.status = 'rejected' THEN
      RAISE EXCEPTION 'El certificado ya está rechazado.';
    END IF;
    IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
      RAISE EXCEPTION 'Indica el motivo del rechazo.';
    END IF;
  END IF;

  UPDATE public.certifications
  SET status = CASE WHEN p_approve THEN 'verified' ELSE 'rejected' END,
      rejection_reason = CASE WHEN p_approve THEN NULL ELSE trim(p_reason) END,
      reviewed_by = auth.uid(),
      reviewed_at = timezone('utc'::text, now())
  WHERE id = p_certification_id
  RETURNING * INTO v_cert;

  RETURN v_cert;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.review_certification(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_certification(UUID, BOOLEAN, TEXT) TO authenticated;

-- ==============================================================================
-- 5. CAMPO CALCULADO: offers.verified_certifications
-- ==============================================================================
-- PostgREST lo expone como columna: .select('*, verified_certifications').
-- Compara nombres sin distinguir mayúsculas ni espacios, e ignora certificados
-- vencidos. SECURITY DEFINER porque los importadores no ven la tabla.
CREATE OR REPLACE FUNCTION public.verified_certifications(o public.offers)
RETURNS TEXT[] AS $$
  SELECT COALESCE(array_agg(DISTINCT oc ORDER BY oc), '{}')
  FROM unnest(o.certifications) AS oc
  WHERE EXISTS (
    SELECT 1 FROM public.certifications c
    WHERE c.seller_id = o.seller_id
      AND c.status = 'verified'
      AND lower(trim(c.name)) = lower(trim(oc))
      AND (c.valid_until IS NULL OR c.valid_until >= current_date)
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.verified_certifications(public.offers) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verified_certifications(public.offers) TO authenticated;

-- ==============================================================================
-- 6. POLÍTICAS: tabla certifications
-- ==============================================================================
ALTER TABLE public.certifications ENABLE ROW LEVEL SECURITY;

-- Los cambios de estado solo van por review_certification.
REVOKE UPDATE ON public.certifications FROM authenticated, anon;

DROP POLICY IF EXISTS "Owners and offer managers can view certifications" ON public.certifications;
CREATE POLICY "Owners and offer managers can view certifications"
  ON public.certifications FOR SELECT
  TO authenticated
  USING (seller_id = auth.uid() OR public.has_permission('offerManagement'));

DROP POLICY IF EXISTS "Exporters can register certifications" ON public.certifications;
CREATE POLICY "Exporters can register certifications"
  ON public.certifications FOR INSERT
  TO authenticated
  WITH CHECK (seller_id = auth.uid() AND status = 'pending');

-- El dueño borra los pendientes o rechazados; un certificado verificado es
-- evidencia y solo lo retira un admin.
DROP POLICY IF EXISTS "Owners delete unverified, managers delete any" ON public.certifications;
CREATE POLICY "Owners delete unverified, managers delete any"
  ON public.certifications FOR DELETE
  TO authenticated
  USING (
    (seller_id = auth.uid() AND status IN ('pending', 'rejected'))
    OR public.has_permission('offerManagement')
  );

-- ==============================================================================
-- 7. POLÍTICAS: archivos del bucket (storage.objects)
-- ==============================================================================
DROP POLICY IF EXISTS "Exporters upload certificates to own folder" ON storage.objects;
CREATE POLICY "Exporters upload certificates to own folder"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'certifications'
    AND (storage.foldername(name))[1] = auth.uid()::text
    AND NOT public.is_blocked()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'exportador')
  );

DROP POLICY IF EXISTS "Owners and offer managers read certificates" ON storage.objects;
CREATE POLICY "Owners and offer managers read certificates"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'certifications'
    AND ((storage.foldername(name))[1] = auth.uid()::text
         OR public.has_permission('offerManagement'))
  );

-- El archivo de un certificado verificado no se puede borrar (primero hay que
-- retirar el registro); los demás los borra su dueño o un admin.
DROP POLICY IF EXISTS "Owners delete unverified certificate files" ON storage.objects;
CREATE POLICY "Owners delete unverified certificate files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'certifications'
    AND (
      public.has_permission('offerManagement')
      OR (
        (storage.foldername(name))[1] = auth.uid()::text
        AND NOT EXISTS (
          SELECT 1 FROM public.certifications c
          WHERE c.file_path = storage.objects.name AND c.status = 'verified'
        )
      )
    )
  );
