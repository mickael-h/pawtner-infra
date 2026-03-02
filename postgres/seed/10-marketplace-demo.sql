-- Marketplace demo schema + seed data for local development.
-- Source values are mapped from pawtner-app/src/features/shared/data/mockData.ts.
-- This script is idempotent and safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS marketplace_users (
  id UUID PRIMARY KEY,
  keycloak_username TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK (role IN ('merchant', 'client')),
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS merchant_profiles (
  merchant_user_id UUID PRIMARY KEY REFERENCES marketplace_users(id) ON DELETE CASCADE,
  profile_code TEXT NOT NULL UNIQUE,
  label_score INTEGER NOT NULL CHECK (label_score BETWEEN 0 AND 100),
  is_certified BOOLEAN NOT NULL DEFAULT FALSE,
  is_family_style BOOLEAN NOT NULL DEFAULT FALSE,
  location TEXT NOT NULL,
  specialties TEXT[] NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS marketplace_offers (
  id UUID PRIMARY KEY,
  offer_code TEXT NOT NULL UNIQUE,
  merchant_user_id UUID NOT NULL REFERENCES marketplace_users(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  animal_type TEXT NOT NULL CHECK (animal_type IN ('dog', 'cat', 'horse')),
  breed TEXT NOT NULL,
  gender TEXT NOT NULL CHECK (gender IN ('M', 'F')),
  birth_date DATE NOT NULL,
  price_eur NUMERIC(10, 2) NOT NULL CHECK (price_eur >= 0),
  location TEXT NOT NULL,
  listing_type TEXT NOT NULL CHECK (listing_type IN ('sale', 'stud')),
  image_url TEXT NOT NULL,
  cycle_status TEXT CHECK (cycle_status IN ('rest', 'heat', 'pregnancy', 'nursing')),
  is_available_for_club BOOLEAN NOT NULL DEFAULT FALSE,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS merchant_reviews (
  id UUID PRIMARY KEY,
  review_code TEXT NOT NULL UNIQUE,
  merchant_user_id UUID NOT NULL REFERENCES marketplace_users(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT NOT NULL,
  reviewed_at DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS marketplace_orders (
  id UUID PRIMARY KEY,
  order_code TEXT NOT NULL UNIQUE,
  client_user_id UUID NOT NULL REFERENCES marketplace_users(id) ON DELETE RESTRICT,
  merchant_user_id UUID NOT NULL REFERENCES marketplace_users(id) ON DELETE RESTRICT,
  offer_id UUID NOT NULL REFERENCES marketplace_offers(id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  amount_eur NUMERIC(10, 2) NOT NULL CHECK (amount_eur >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS marketplace_monthly_sales_metrics (
  id UUID PRIMARY KEY,
  metric_code TEXT NOT NULL UNIQUE,
  metric_year INTEGER NOT NULL CHECK (metric_year >= 2000),
  month_index INTEGER NOT NULL CHECK (month_index BETWEEN 1 AND 12),
  merchant_user_id UUID REFERENCES marketplace_users(id) ON DELETE CASCADE,
  amount_eur NUMERIC(10, 2) NOT NULL CHECK (amount_eur >= 0)
);

INSERT INTO marketplace_users (id, keycloak_username, role, email, display_name) VALUES
  ('11111111-1111-4111-8111-111111111111', 'merchant_demo', 'merchant', 'merchant.demo@pawtner.local', 'Merchant Demo'),
  ('11111111-1111-4111-8111-111111111112', 'merchant_b2', 'merchant', 'merchant.b2@pawtner.local', 'Passion Canis'),
  ('11111111-1111-4111-8111-111111111113', 'merchant_b3', 'merchant', 'merchant.b3@pawtner.local', 'Haras des Plaines'),
  ('22222222-2222-4222-8222-222222222221', 'client_demo', 'client', 'client.demo@pawtner.local', 'Client Demo'),
  ('22222222-2222-4222-8222-222222222222', 'client_alice', 'client', 'alice.client@pawtner.local', 'Alice Martin')
ON CONFLICT (id) DO UPDATE SET
  keycloak_username = EXCLUDED.keycloak_username,
  role = EXCLUDED.role,
  email = EXCLUDED.email,
  display_name = EXCLUDED.display_name;

INSERT INTO merchant_profiles (
  merchant_user_id, profile_code, label_score, is_certified, is_family_style, location, specialties
) VALUES
  ('11111111-1111-4111-8111-111111111111', 'b1', 95, TRUE, TRUE, 'Lyon, FR', ARRAY['Golden Retriever', 'Maine Coon']),
  ('11111111-1111-4111-8111-111111111112', 'b2', 88, TRUE, FALSE, 'Bordeaux, FR', ARRAY['Berger Australien']),
  ('11111111-1111-4111-8111-111111111113', 'b3', 92, TRUE, FALSE, 'Normandie, FR', ARRAY['Pur-sang Arabe', 'Selle Francais'])
ON CONFLICT (merchant_user_id) DO UPDATE SET
  profile_code = EXCLUDED.profile_code,
  label_score = EXCLUDED.label_score,
  is_certified = EXCLUDED.is_certified,
  is_family_style = EXCLUDED.is_family_style,
  location = EXCLUDED.location,
  specialties = EXCLUDED.specialties;

INSERT INTO marketplace_offers (
  id, offer_code, merchant_user_id, name, animal_type, breed, gender, birth_date, price_eur, location,
  listing_type, image_url, cycle_status, is_available_for_club, description, status
) VALUES
  (
    '33333333-3333-4333-8333-333333333331', 'a1', '11111111-1111-4111-8111-111111111111',
    'Rudy', 'dog', 'Golden Retriever', 'M', DATE '2023-05-12', 1800, 'Lyon, FR', 'sale',
    'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&q=80&w=800',
    NULL, FALSE, 'Chiot exceptionnel, vaccine et puce. Caractere tres doux.', 'published'
  ),
  (
    '33333333-3333-4333-8333-333333333332', 'a2', '11111111-1111-4111-8111-111111111111',
    'Luna', 'cat', 'Maine Coon', 'F', DATE '2022-10-05', 1500, 'Lyon, FR', 'sale',
    'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?auto=format&fit=crop&q=80&w=800',
    'rest', FALSE, 'Magnifique femelle Maine Coon pour compagnie ou reproduction.', 'published'
  ),
  (
    '33333333-3333-4333-8333-333333333333', 'a3', '11111111-1111-4111-8111-111111111112',
    'Max', 'dog', 'Berger Australien', 'M', DATE '2021-02-15', 800, 'Bordeaux, FR', 'stud',
    'https://images.unsplash.com/photo-1506755855567-92ff770e8d00?auto=format&fit=crop&q=80&w=800',
    NULL, TRUE, 'Etalon confirme, excellent pedigree, disponible pour saillies.', 'published'
  ),
  (
    '33333333-3333-4333-8333-333333333334', 'a4', '11111111-1111-4111-8111-111111111113',
    'Storm', 'horse', 'Pur-sang Arabe', 'M', DATE '2020-04-10', 12500, 'Normandie, FR', 'sale',
    'https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?auto=format&fit=crop&q=80&w=800',
    NULL, FALSE, 'Etalon Pur-sang Arabe avec un pedigree prestigieux. Tres agile et equilibre.', 'published'
  ),
  (
    '33333333-3333-4333-8333-333333333335', 'a5', '11111111-1111-4111-8111-111111111113',
    'Gaia', 'horse', 'Selle Francais', 'F', DATE '2019-06-22', 9800, 'Normandie, FR', 'sale',
    'https://images.unsplash.com/photo-1598974357801-cbca100e65d3?auto=format&fit=crop&q=80&w=800',
    NULL, FALSE, 'Jument Selle Francais ideale pour le CSO. Excellente sante et caractere volontaire.', 'published'
  )
ON CONFLICT (id) DO UPDATE SET
  offer_code = EXCLUDED.offer_code,
  merchant_user_id = EXCLUDED.merchant_user_id,
  name = EXCLUDED.name,
  animal_type = EXCLUDED.animal_type,
  breed = EXCLUDED.breed,
  gender = EXCLUDED.gender,
  birth_date = EXCLUDED.birth_date,
  price_eur = EXCLUDED.price_eur,
  location = EXCLUDED.location,
  listing_type = EXCLUDED.listing_type,
  image_url = EXCLUDED.image_url,
  cycle_status = EXCLUDED.cycle_status,
  is_available_for_club = EXCLUDED.is_available_for_club,
  description = EXCLUDED.description,
  status = EXCLUDED.status;

INSERT INTO merchant_reviews (
  id, review_code, merchant_user_id, author_name, rating, comment, reviewed_at
) VALUES
  ('44444444-4444-4444-8444-444444444441', 'r1', '11111111-1111-4111-8111-111111111111', 'Jean D.', 5, 'Eleveur passionne, les chiots sont parfaitement socialises.', DATE '2024-01-15'),
  ('44444444-4444-4444-8444-444444444442', 'r2', '11111111-1111-4111-8111-111111111111', 'Marie L.', 4, 'Tres bon accueil et conseils precieux pour l''arrivee de Luna.', DATE '2023-11-20'),
  ('44444444-4444-4444-8444-444444444443', 'r3', '11111111-1111-4111-8111-111111111111', 'Paul B.', 5, 'Installation exemplaire. Hygiene irreprochable.', DATE '2024-02-01'),
  ('44444444-4444-4444-8444-444444444444', 'r4', '11111111-1111-4111-8111-111111111112', 'Sophie K.', 4, 'Max est un chien adorable et en pleine sante. Merci.', DATE '2023-12-10'),
  ('44444444-4444-4444-8444-444444444445', 'r5', '11111111-1111-4111-8111-111111111112', 'Lucas M.', 3, 'Un peu difficile a joindre mais l''elevage est serieux.', DATE '2024-01-05'),
  ('44444444-4444-4444-8444-444444444446', 'r6', '11111111-1111-4111-8111-111111111113', 'Nicolas V.', 5, 'Chevaux d''exception, installations magnifiques et soins de haute qualite.', DATE '2024-03-10')
ON CONFLICT (id) DO UPDATE SET
  review_code = EXCLUDED.review_code,
  merchant_user_id = EXCLUDED.merchant_user_id,
  author_name = EXCLUDED.author_name,
  rating = EXCLUDED.rating,
  comment = EXCLUDED.comment,
  reviewed_at = EXCLUDED.reviewed_at;

-- Seed a few orders so the client dashboard has real data to follow.
INSERT INTO marketplace_orders (
  id, order_code, client_user_id, merchant_user_id, offer_id, status, amount_eur
) VALUES
  ('55555555-5555-4555-8555-555555555551', 'o1', '22222222-2222-4222-8222-222222222221', '11111111-1111-4111-8111-111111111111', '33333333-3333-4333-8333-333333333331', 'completed', 1800),
  ('55555555-5555-4555-8555-555555555552', 'o2', '22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111113', '33333333-3333-4333-8333-333333333335', 'confirmed', 9800),
  ('55555555-5555-4555-8555-555555555553', 'o3', '22222222-2222-4222-8222-222222222221', '11111111-1111-4111-8111-111111111112', '33333333-3333-4333-8333-333333333333', 'pending', 800)
ON CONFLICT (id) DO UPDATE SET
  order_code = EXCLUDED.order_code,
  client_user_id = EXCLUDED.client_user_id,
  merchant_user_id = EXCLUDED.merchant_user_id,
  offer_id = EXCLUDED.offer_id,
  status = EXCLUDED.status,
  amount_eur = EXCLUDED.amount_eur,
  updated_at = NOW();

INSERT INTO marketplace_monthly_sales_metrics (
  id, metric_code, metric_year, month_index, merchant_user_id, amount_eur
) VALUES
  ('66666666-6666-4666-8666-666666666661', 'ms-2025-01', 2025, 1, NULL, 8600),
  ('66666666-6666-4666-8666-666666666662', 'ms-2025-02', 2025, 2, NULL, 9200),
  ('66666666-6666-4666-8666-666666666663', 'ms-2025-03', 2025, 3, NULL, 10100),
  ('66666666-6666-4666-8666-666666666664', 'ms-2025-04', 2025, 4, NULL, 9700),
  ('66666666-6666-4666-8666-666666666665', 'ms-2025-05', 2025, 5, NULL, 11200),
  ('66666666-6666-4666-8666-666666666666', 'ms-2025-06', 2025, 6, NULL, 12400)
ON CONFLICT (id) DO UPDATE SET
  metric_code = EXCLUDED.metric_code,
  metric_year = EXCLUDED.metric_year,
  month_index = EXCLUDED.month_index,
  merchant_user_id = EXCLUDED.merchant_user_id,
  amount_eur = EXCLUDED.amount_eur;

COMMIT;
