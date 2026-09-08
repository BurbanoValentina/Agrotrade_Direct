-- ==============================================================================
-- AgroTrade Direct — Esquema de Base de Datos para Supabase (PostgreSQL)
-- Diseñado para: RiTech SAS | Rol: Backend & Database Engineer (Johan Delgado)
-- Cobertura: REQ-02 a REQ-19 (Perfiles, Catálogo de Commodities y Negociación P2P)
-- ==============================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 2. TABLA: profiles (Extensión del usuario auth.users)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('exportador', 'importador')),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  company_name TEXT,
  country TEXT,
  rating NUMERIC(3, 2) DEFAULT 5.0 CHECK (rating >= 0 AND rating <= 5.0),
  completed_trades INT DEFAULT 0 CHECK (completed_trades >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de profiles
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- ==============================================================================
-- 3. TABLA: offers (Catálogo de Café y Cacao para Live Market - REQ-06 a REQ-13)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  crop_type TEXT NOT NULL CHECK (crop_type IN ('cafe', 'cacao')),
  variety TEXT NOT NULL,
  origin_region TEXT NOT NULL,
  origin_country TEXT NOT NULL DEFAULT 'Colombia',
  ask_price_per_mt NUMERIC(10, 2) NOT NULL CHECK (ask_price_per_mt > 0),
  volume_mt NUMERIC(10, 2) NOT NULL CHECK (volume_mt > 0),
  destination_country TEXT NOT NULL,
  certifications TEXT[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'activa' CHECK (status IN ('activa', 'negociando', 'confirmada', 'enTransito', 'cerrada')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de offers para búsqueda y filtros rápidos
CREATE INDEX IF NOT EXISTS idx_offers_crop_type ON public.offers(crop_type);
CREATE INDEX IF NOT EXISTS idx_offers_status ON public.offers(status);
CREATE INDEX IF NOT EXISTS idx_offers_seller_id ON public.offers(seller_id);
CREATE INDEX IF NOT EXISTS idx_offers_origin_region ON public.offers(origin_region);

-- ==============================================================================
-- 4. TABLA: negotiations (Solicitudes y Contraofertas estilo InDrive - REQ-14 a REQ-17, REQ-19)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.negotiations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id UUID NOT NULL REFERENCES public.offers(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  proposed_price_per_mt NUMERIC(10, 2) NOT NULL CHECK (proposed_price_per_mt > 0),
  requested_volume_mt NUMERIC(10, 2) NOT NULL CHECK (requested_volume_mt > 0),
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'countered', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de negotiations para consultas de 'My Deals'
CREATE INDEX IF NOT EXISTS idx_negotiations_offer_id ON public.negotiations(offer_id);
CREATE INDEX IF NOT EXISTS idx_negotiations_buyer_id ON public.negotiations(buyer_id);
CREATE INDEX IF NOT EXISTS idx_negotiations_seller_id ON public.negotiations(seller_id);
CREATE INDEX IF NOT EXISTS idx_negotiations_status ON public.negotiations(status);

-- ==============================================================================
-- 5. TRIGGER AUTOMÁTICO: Crear perfil al registrarse en Supabase Auth
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, role, name, email, company_name, country)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'role', 'importador'),
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    NEW.email,
    NEW.raw_user_meta_data->>'company_name',
    NEW.raw_user_meta_data->>'country'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Eliminar trigger previo si existe y recrearlo
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 6. TRIGGER AUTOMÁTICO: Actualizar columna updated_at
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_offers_updated_at ON public.offers;
CREATE TRIGGER set_offers_updated_at
  BEFORE UPDATE ON public.offers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_negotiations_updated_at ON public.negotiations;
CREATE TRIGGER set_negotiations_updated_at
  BEFORE UPDATE ON public.negotiations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ==============================================================================
-- 7. SEGURIDAD (Row Level Security - RLS)
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.negotiations ENABLE ROW LEVEL SECURITY;

-- Políticas para profiles:
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles are viewable by authenticated users"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Políticas para offers:
DROP POLICY IF EXISTS "Offers are viewable by authenticated users" ON public.offers;
CREATE POLICY "Offers are viewable by authenticated users"
  ON public.offers FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Exporters can create offers" ON public.offers;
CREATE POLICY "Exporters can create offers"
  ON public.offers FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = seller_id AND 
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'exportador')
  );

DROP POLICY IF EXISTS "Sellers can update their own offers" ON public.offers;
CREATE POLICY "Sellers can update their own offers"
  ON public.offers FOR UPDATE
  TO authenticated
  USING (auth.uid() = seller_id);

-- Políticas para negotiations (REQ-14):
DROP POLICY IF EXISTS "Importers can create purchase requests" ON public.negotiations;
CREATE POLICY "Importers can create purchase requests"
  ON public.negotiations FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = buyer_id AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'importador')
  );

DROP POLICY IF EXISTS "Parties involved can view negotiations" ON public.negotiations;
CREATE POLICY "Parties involved can view negotiations"
  ON public.negotiations FOR SELECT
  TO authenticated
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

DROP POLICY IF EXISTS "Parties involved can update negotiations" ON public.negotiations;
CREATE POLICY "Parties involved can update negotiations"
  ON public.negotiations FOR UPDATE
  TO authenticated
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

