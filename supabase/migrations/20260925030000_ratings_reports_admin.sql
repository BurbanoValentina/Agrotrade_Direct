-- ==============================================================================
-- AgroTrade Direct — Migración 0004: Calificaciones, reportes y datos del panel admin
-- REQ-23: Cierre de la base de datos (usuarios, productos y operaciones).
-- Base para REQ-21 (calificaciones), REQ-22 (reportes), REQ-33 (panel admin)
-- y REQ-37 (KPIs).
--
-- * ratings: calificación entre las partes de una negociación aceptada.
-- * user_reports: reportes de usuarios, resueltos por admins (userManagement).
-- * suspicious_activities: alertas de seguridad (permiso security), incluida
--   la detección automática de precios anómalos.
-- * platform_config: configuración global (comisión, precios de referencia).
-- * admin_dashboard_stats(): números del dashboard del panel admin.
--
-- Los valores de texto de estados, tipos y severidades coinciden con los enums
-- de Flutter (lib/models/suspicious_activity.dart).
-- ==============================================================================

-- ==============================================================================
-- 1. TABLA: ratings (REQ-21)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id UUID NOT NULL REFERENCES public.negotiations(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rated_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment TEXT CHECK (comment IS NULL OR length(comment) <= 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  -- Cada parte califica una sola vez por negociación.
  UNIQUE (negotiation_id, rater_id),
  CHECK (rater_id <> rated_id)
);

CREATE INDEX IF NOT EXISTS idx_ratings_rated_id ON public.ratings(rated_id);

-- profiles.rating = promedio real de las calificaciones recibidas (5.0 si no hay).
CREATE OR REPLACE FUNCTION public.refresh_profile_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_user UUID := COALESCE(NEW.rated_id, OLD.rated_id);
BEGIN
  UPDATE public.profiles
  SET rating = COALESCE(
    (SELECT round(avg(score)::numeric, 2) FROM public.ratings WHERE rated_id = v_user),
    5.0
  )
  WHERE id = v_user;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS refresh_profile_rating ON public.ratings;
CREATE TRIGGER refresh_profile_rating
  AFTER INSERT OR DELETE ON public.ratings
  FOR EACH ROW EXECUTE FUNCTION public.refresh_profile_rating();

-- ==============================================================================
-- 2. TABLA: user_reports (REQ-22 / REQ-33)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.user_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  negotiation_id UUID REFERENCES public.negotiations(id) ON DELETE SET NULL,
  category TEXT NOT NULL CHECK (category IN (
    'fraude', 'incumplimiento', 'conductaInapropiada', 'informacionFalsa', 'otro'
  )),
  description TEXT NOT NULL CHECK (length(trim(description)) BETWEEN 10 AND 2000),
  status TEXT NOT NULL DEFAULT 'pendiente' CHECK (status IN (
    'pendiente', 'revisada', 'descartada', 'accionTomada'
  )),
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CHECK (reporter_id <> reported_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_status ON public.user_reports(status);
CREATE INDEX IF NOT EXISTS idx_user_reports_reported ON public.user_reports(reported_user_id);

DROP TRIGGER IF EXISTS set_user_reports_updated_at ON public.user_reports;
CREATE TRIGGER set_user_reports_updated_at
  BEFORE UPDATE ON public.user_reports
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ==============================================================================
-- 3. TABLA: suspicious_activities (panel de seguridad)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.suspicious_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN (
    'precioAnomalo', 'multiplesCuentas', 'patronInusual', 'intentoFraude'
  )),
  description TEXT NOT NULL,
  related_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  related_offer_id UUID REFERENCES public.offers(id) ON DELETE SET NULL,
  severity TEXT NOT NULL CHECK (severity IN ('baja', 'media', 'alta', 'critica')),
  status TEXT NOT NULL DEFAULT 'pendiente' CHECK (status IN (
    'pendiente', 'revisada', 'descartada', 'accionTomada'
  )),
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  detected_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_suspicious_status ON public.suspicious_activities(status);
CREATE INDEX IF NOT EXISTS idx_suspicious_user ON public.suspicious_activities(related_user_id);

-- ==============================================================================
-- 4. TABLA: platform_config (una sola fila)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.platform_config (
  id BOOLEAN PRIMARY KEY DEFAULT true CHECK (id),
  commission_percent NUMERIC(5, 2) NOT NULL CHECK (commission_percent BETWEEN 0 AND 100),
  arabica_ref_price NUMERIC(10, 2) NOT NULL CHECK (arabica_ref_price > 0),
  cacao_ref_price NUMERIC(10, 2) NOT NULL CHECK (cacao_ref_price > 0),
  usd_eur_rate NUMERIC(10, 4) NOT NULL CHECK (usd_eur_rate > 0),
  -- Desviación (%) respecto al precio de referencia a partir de la cual una
  -- oferta genera una alerta de precio anómalo.
  anomaly_threshold_percent NUMERIC(5, 2) NOT NULL DEFAULT 40 CHECK (anomaly_threshold_percent > 0),
  updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Valores iniciales = defaultPlatformConfig de Flutter (mock_admin_data.dart).
INSERT INTO public.platform_config (commission_percent, arabica_ref_price, cacao_ref_price, usd_eur_rate)
VALUES (2.5, 4210, 6870, 0.921)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.set_platform_config_audit()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := timezone('utc'::text, now());
  IF auth.uid() IS NOT NULL THEN
    NEW.updated_by := auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS set_platform_config_audit ON public.platform_config;
CREATE TRIGGER set_platform_config_audit
  BEFORE UPDATE ON public.platform_config
  FOR EACH ROW EXECUTE FUNCTION public.set_platform_config_audit();

-- ==============================================================================
-- 5. REGLAS DE REVISIÓN (reportes y alertas)
-- ==============================================================================
-- Un admin solo cambia el estado y la resolución; el contenido del reporte o de
-- la alerta no se altera. reviewed_by / reviewed_at se completan solos.
CREATE OR REPLACE FUNCTION public.enforce_review_update()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'user_reports' THEN
    IF NEW.reporter_id IS DISTINCT FROM OLD.reporter_id
       OR NEW.reported_user_id IS DISTINCT FROM OLD.reported_user_id
       OR NEW.negotiation_id IS DISTINCT FROM OLD.negotiation_id
       OR NEW.category IS DISTINCT FROM OLD.category
       OR NEW.description IS DISTINCT FROM OLD.description
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Solo se puede cambiar el estado y la resolución del reporte';
    END IF;
  ELSE
    IF NEW.type IS DISTINCT FROM OLD.type
       OR NEW.description IS DISTINCT FROM OLD.description
       OR NEW.related_user_id IS DISTINCT FROM OLD.related_user_id
       OR NEW.related_offer_id IS DISTINCT FROM OLD.related_offer_id
       OR NEW.severity IS DISTINCT FROM OLD.severity
       OR NEW.detected_at IS DISTINCT FROM OLD.detected_at THEN
      RAISE EXCEPTION 'Solo se puede cambiar el estado de la alerta';
    END IF;
    NEW.reviewed_at := timezone('utc'::text, now());
  END IF;

  NEW.reviewed_by := auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS enforce_review_update ON public.user_reports;
CREATE TRIGGER enforce_review_update
  BEFORE UPDATE ON public.user_reports
  FOR EACH ROW EXECUTE FUNCTION public.enforce_review_update();

DROP TRIGGER IF EXISTS enforce_review_update ON public.suspicious_activities;
CREATE TRIGGER enforce_review_update
  BEFORE UPDATE ON public.suspicious_activities
  FOR EACH ROW EXECUTE FUNCTION public.enforce_review_update();

-- ==============================================================================
-- 6. DETECCIÓN AUTOMÁTICA DE PRECIOS ANÓMALOS
-- ==============================================================================
-- Al publicar una oferta o cambiar su precio, si se desvía más de
-- anomaly_threshold_percent del precio de referencia se crea una alerta.
-- Severidad: < 60 % media · < 100 % alta · >= 100 % crítica.
CREATE OR REPLACE FUNCTION public.detect_price_anomaly()
RETURNS TRIGGER AS $$
DECLARE
  v_config public.platform_config%ROWTYPE;
  v_ref NUMERIC;
  v_deviation NUMERIC;
  v_severity TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.ask_price_per_mt IS NOT DISTINCT FROM OLD.ask_price_per_mt THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_config FROM public.platform_config WHERE id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF NEW.crop_type = 'cafe' THEN
    v_ref := v_config.arabica_ref_price;
  ELSE
    v_ref := v_config.cacao_ref_price;
  END IF;

  -- Se redondea una sola vez para que el texto y la severidad coincidan.
  v_deviation := round(abs(NEW.ask_price_per_mt - v_ref) / v_ref * 100);
  IF v_deviation <= v_config.anomaly_threshold_percent THEN
    RETURN NULL;
  END IF;

  v_severity := CASE
    WHEN v_deviation < 60 THEN 'media'
    WHEN v_deviation < 100 THEN 'alta'
    ELSE 'critica'
  END;

  INSERT INTO public.suspicious_activities
    (type, description, related_user_id, related_offer_id, severity)
  VALUES (
    'precioAnomalo',
    format(
      'Oferta "%s" a %s USD/MT: %s%% %s del precio de referencia (%s USD/MT).',
      NEW.variety, NEW.ask_price_per_mt, v_deviation,
      CASE WHEN NEW.ask_price_per_mt > v_ref THEN 'por encima' ELSE 'por debajo' END,
      v_ref
    ),
    NEW.seller_id,
    NEW.id,
    v_severity
  );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS detect_price_anomaly ON public.offers;
CREATE TRIGGER detect_price_anomaly
  AFTER INSERT OR UPDATE OF ask_price_per_mt ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.detect_price_anomaly();

REVOKE EXECUTE ON FUNCTION public.refresh_profile_rating(), public.detect_price_anomaly()
  FROM PUBLIC, authenticated, anon;

-- ==============================================================================
-- 7. RPC: admin_dashboard_stats() (panel admin / REQ-37)
-- ==============================================================================
-- Claves en camelCase = campos de DashboardStats en Flutter:
--   final data = await supabase.rpc('admin_dashboard_stats');
CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS JSON AS $$
BEGIN
  IF NOT public.has_permission('dashboard') THEN
    RAISE EXCEPTION 'Requiere el permiso dashboard';
  END IF;

  RETURN json_build_object(
    'totalUsers', (SELECT count(*) FROM public.profiles WHERE role IN ('exportador', 'importador')),
    'activeOffers', (SELECT count(*) FROM public.offers WHERE status IN ('activa', 'negociando')),
    'activeNegotiations', (SELECT count(*) FROM public.negotiations WHERE status IN ('pending', 'countered')),
    'blockedUsers', (SELECT count(*) FROM public.blocked_users),
    'pendingAlerts', (SELECT count(*) FROM public.suspicious_activities WHERE status = 'pendiente'),
    'totalVolumeMt', (SELECT COALESCE(sum(requested_volume_mt), 0) FROM public.negotiations WHERE status = 'accepted'),
    'totalValueUsd', (SELECT COALESCE(sum(requested_volume_mt * proposed_price_per_mt), 0) FROM public.negotiations WHERE status = 'accepted')
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;

-- ==============================================================================
-- 8. POLÍTICAS RLS
-- ==============================================================================
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suspicious_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_config ENABLE ROW LEVEL SECURITY;

-- ratings: públicas para usuarios autenticados (sistema de confianza).
DROP POLICY IF EXISTS "Ratings are viewable by authenticated users" ON public.ratings;
CREATE POLICY "Ratings are viewable by authenticated users"
  ON public.ratings FOR SELECT
  TO authenticated
  USING (true);

-- Solo las partes de una negociación aceptada, calificando a la contraparte.
DROP POLICY IF EXISTS "Parties of an accepted deal can rate each other" ON public.ratings;
CREATE POLICY "Parties of an accepted deal can rate each other"
  ON public.ratings FOR INSERT
  TO authenticated
  WITH CHECK (
    rater_id = auth.uid() AND
    NOT public.is_blocked() AND
    EXISTS (
      SELECT 1 FROM public.negotiations n
      WHERE n.id = ratings.negotiation_id
        AND n.status = 'accepted'
        AND (
          (n.buyer_id = auth.uid() AND n.seller_id = ratings.rated_id) OR
          (n.seller_id = auth.uid() AND n.buyer_id = ratings.rated_id)
        )
    )
  );

-- Las calificaciones no se editan; un moderador puede retirarlas.
DROP POLICY IF EXISTS "User managers can remove ratings" ON public.ratings;
CREATE POLICY "User managers can remove ratings"
  ON public.ratings FOR DELETE
  TO authenticated
  USING (public.has_permission('userManagement'));

-- user_reports
DROP POLICY IF EXISTS "Reporters see own reports, managers see all" ON public.user_reports;
CREATE POLICY "Reporters see own reports, managers see all"
  ON public.user_reports FOR SELECT
  TO authenticated
  USING (reporter_id = auth.uid() OR public.has_permission('userManagement'));

DROP POLICY IF EXISTS "Users can report other users" ON public.user_reports;
CREATE POLICY "Users can report other users"
  ON public.user_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    reporter_id = auth.uid() AND
    status = 'pendiente' AND
    reviewed_by IS NULL AND
    resolution IS NULL
  );

DROP POLICY IF EXISTS "User managers can review reports" ON public.user_reports;
CREATE POLICY "User managers can review reports"
  ON public.user_reports FOR UPDATE
  TO authenticated
  USING (public.has_permission('userManagement'))
  WITH CHECK (public.has_permission('userManagement'));

-- suspicious_activities: solo personal con permiso security. Las alertas las
-- crea el sistema (triggers), no la app.
DROP POLICY IF EXISTS "Security staff can view alerts" ON public.suspicious_activities;
CREATE POLICY "Security staff can view alerts"
  ON public.suspicious_activities FOR SELECT
  TO authenticated
  USING (public.has_permission('security'));

DROP POLICY IF EXISTS "Security staff can review alerts" ON public.suspicious_activities;
CREATE POLICY "Security staff can review alerts"
  ON public.suspicious_activities FOR UPDATE
  TO authenticated
  USING (public.has_permission('security'))
  WITH CHECK (public.has_permission('security'));

REVOKE INSERT, DELETE, TRUNCATE ON public.suspicious_activities FROM authenticated, anon;

-- platform_config: lectura para todos los autenticados, edición con settings.
DROP POLICY IF EXISTS "Config is readable by authenticated users" ON public.platform_config;
CREATE POLICY "Config is readable by authenticated users"
  ON public.platform_config FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Settings staff can update config" ON public.platform_config;
CREATE POLICY "Settings staff can update config"
  ON public.platform_config FOR UPDATE
  TO authenticated
  USING (public.has_permission('settings'))
  WITH CHECK (public.has_permission('settings'));

REVOKE INSERT, DELETE, TRUNCATE ON public.platform_config FROM authenticated, anon;
