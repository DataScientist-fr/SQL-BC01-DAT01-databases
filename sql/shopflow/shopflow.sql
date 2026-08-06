-- ============================================================
--  ShopFlow — schéma PostgreSQL
--  Portage du schéma SQLite du cours SQL BC01-DAT01-01
-- ============================================================
--
--  QUATRE CHOIX DE CONCEPTION :
--
--  1. unit_price est en NUMERIC(10,2), pas en double precision.
--     La plateforme le stocke en REAL, mais les vues du cours écrivent
--     ROUND(SUM(quantity * unit_price), 2) — et PostgreSQL n'a PAS de
--     round(double precision, integer) : la requête échouerait.
--
--  2. order_items garde une clé technique order_item_id.
--     Le MLD *enseigné* au chapitre 3.2 demande PRIMARY KEY
--     (order_id, product_id) — c'est la bonne réponse à l'exercice.
--     Mais la base réelle de la plateforme a une clé technique, et
--     l'anti-jointure du chapitre 4.1 teste oi.order_item_id IS NULL.
--     On garde donc la clé technique : fidélité aux exercices.
--
--  3. is_active reste un INTEGER 0/1, pas un BOOLEAN.
--     Les solutions du cours écrivent WHERE is_active = 1.
--
--  4. order_date et signup_date restent en TEXT ('YYYY-MM-DD').
--     Même arbitrage que scheduled_at dans CareAccess. La vue
--     `orders_typed` expose la vraie DATE.
--
--  LES DEUX POINTS PÉDAGOGIQUES DE CETTE BASE :
--   - le fan-out : orders (8) jointe à order_items donne 15 lignes ;
--   - order_items.unit_price est le prix AU MOMENT DE LA COMMANDE, il
--     diffère volontairement de products.unit_price (catalogue). Ne
--     jamais calculer un CA depuis products.
-- ============================================================

DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders      CASCADE;
DROP TABLE IF EXISTS products    CASCADE;
DROP TABLE IF EXISTS customers   CASCADE;
DROP TABLE IF EXISTS categories  CASCADE;

-- ------------------------------------------------------------
-- Grain : une ligne = une catégorie (entité, hiérarchie)
-- FK réflexive : NULL = catégorie racine
-- ------------------------------------------------------------
CREATE TABLE categories (
    category_id        SERIAL PRIMARY KEY,
    category_name      TEXT NOT NULL,
    parent_category_id INTEGER REFERENCES categories(category_id)  -- nullable : racines
);

COMMENT ON TABLE  categories                    IS
  'Grain : une catégorie. FK réflexive -> support du self-join du chapitre 4.2.';
COMMENT ON COLUMN categories.parent_category_id IS 'NULL = catégorie racine.';

-- ------------------------------------------------------------
-- Grain : une ligne = un client (entité)
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    email         TEXT,            -- nullable : Bruno Lefef (2), Emeka Obi (5)
    country       TEXT NOT NULL,
    signup_date   TEXT NOT NULL    -- 'YYYY-MM-DD' (cf. note en tête)
);

COMMENT ON TABLE customers IS
  'Grain : un client. 7 lignes, dont Gaël Morin (7) qui n''a AUCUNE commande -> anti-jointure.';

-- ------------------------------------------------------------
-- Grain : une ligne = un produit du catalogue (entité)
-- ------------------------------------------------------------
CREATE TABLE products (
    product_id   SERIAL PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id  INTEGER NOT NULL REFERENCES categories(category_id),
    unit_price   NUMERIC(10,2) NOT NULL,   -- prix CATALOGUE (cf. note en tête)
    is_active    INTEGER NOT NULL          -- 0/1, pas un booléen (cf. note en tête)
);

COMMENT ON TABLE  products            IS
  'Grain : un produit. 8 lignes, dont Grille-pain vintage (8) jamais commandé -> anti-jointure.';
COMMENT ON COLUMN products.unit_price IS
  'Prix catalogue actuel. Le prix facturé est order_items.unit_price.';

-- ------------------------------------------------------------
-- Grain : une ligne = une commande (transactionnel)
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date  TEXT NOT NULL,   -- 'YYYY-MM-DD'
    status      TEXT NOT NULL,   -- paid / shipped / cancelled / pending
    channel     TEXT NOT NULL    -- web / mobile / store
);

COMMENT ON TABLE orders IS
  'Grain : une commande. 8 lignes. Joindre à order_items produit un fan-out (15 lignes).';

-- ------------------------------------------------------------
-- Grain : une ligne = un produit dans une commande
-- Table de liaison du N-N commande/produit, au grain le PLUS FIN
-- ------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,   -- clé technique (cf. note en tête)
    order_id      INTEGER NOT NULL REFERENCES orders(order_id),
    product_id    INTEGER NOT NULL REFERENCES products(product_id),
    quantity      INTEGER NOT NULL,
    unit_price    NUMERIC(10,2) NOT NULL   -- prix FACTURÉ, historisé
);

COMMENT ON TABLE  order_items            IS
  'Grain : une ligne de commande. 15 lignes pour 8 commandes. C''est la table qui provoque le fan-out.';
COMMENT ON COLUMN order_items.unit_price IS
  'Prix au moment de la commande. Diffère du catalogue : c''est CE prix qui fait le CA.';

-- Index conformes à ce que ferait un vrai système transactionnel
CREATE INDEX idx_products_category    ON products(category_id);
CREATE INDEX idx_orders_customer      ON orders(customer_id);
CREATE INDEX idx_order_items_order    ON order_items(order_id);
CREATE INDEX idx_order_items_product  ON order_items(product_id);
CREATE INDEX idx_categories_parent    ON categories(parent_category_id);
-- ============================================================
--  ShopFlow — données de référence
--  Extrait de la base de test réelle de DataScientist.fr
--  (cours SQL BC01-DAT01-01, chapitres 4.1 à 5.3)
-- ============================================================

-- categories (5 lignes) — deux racines, trois filles
INSERT INTO categories (category_id, category_name, parent_category_id) VALUES
  (1, 'Informatique',  NULL),
  (2, 'Ordinateurs',   1),
  (3, 'Périphériques', 1),
  (4, 'Maison',        NULL),
  (5, 'Cuisine',       4);

-- customers (7 lignes) — Gaël Morin n'a aucune commande
INSERT INTO customers (customer_id, customer_name, email, country, signup_date) VALUES
  (1, 'Alice Durand',  'alice@example.com',  'FR', '2025-02-10'),
  (2, 'Bruno Lefef',   NULL,                 'FR', '2025-03-01'),
  (3, 'Chen Wei',      'chen@example.com',   'BE', '2025-03-15'),
  (4, 'Diana Rossi',   'diana@example.com',  'IT', '2025-04-02'),
  (5, 'Emeka Obi',     NULL,                 'FR', '2025-04-20'),
  (6, 'Fatima Zahra',  'fatima@example.com', 'MA', '2025-05-05'),
  (7, 'Gaël Morin',    'gael@example.com',   'FR', '2025-05-22');

-- products (8 lignes) — Grille-pain vintage jamais commandé
INSERT INTO products (product_id, product_name, category_id, unit_price, is_active) VALUES
  (1, 'Portable Pro 14',     2, 1299.00, 1),
  (2, 'Portable Air 13',     2,  999.00, 1),
  (3, 'Clavier mécanique',   3,   89.90, 1),
  (4, 'Souris ergonomique',  3,   49.90, 1),
  (5, 'Écran 27 pouces',     3,  279.00, 0),   -- inactif, mais présent dans la commande 8
  (6, 'Robot pâtissier',     5,  199.00, 1),
  (7, 'Bouilloire inox',     5,   39.90, 1),
  (8, 'Grille-pain vintage', 5,   59.90, 0);   -- jamais commandé

-- orders (8 lignes)
INSERT INTO orders (order_id, customer_id, order_date, status, channel) VALUES
  (1, 1, '2025-06-01', 'paid',      'web'),
  (2, 1, '2025-06-03', 'shipped',   'mobile'),
  (3, 2, '2025-06-05', 'paid',      'web'),
  (4, 3, '2025-06-07', 'cancelled', 'store'),
  (5, 4, '2025-06-09', 'paid',      'web'),
  (6, 5, '2025-06-10', 'pending',   'mobile'),
  (7, 1, '2025-06-12', 'paid',      'store'),
  (8, 6, '2025-06-15', 'shipped',   'web');

-- order_items (15 lignes pour 8 commandes -> le fan-out)
-- Les unit_price qui s'écartent du catalogue sont VOLONTAIRES : c'est le
-- prix facturé ce jour-là (produit 1 à 1249.00, produit 3 à 79.90, etc.).
INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price) VALUES
  ( 1, 1, 1, 1, 1299.00),
  ( 2, 1, 3, 2,   89.90),
  ( 3, 1, 4, 1,   49.90),
  ( 4, 2, 2, 1,  999.00),
  ( 5, 3, 6, 1,  199.00),
  ( 6, 3, 7, 3,   39.90),
  ( 7, 4, 3, 1,   79.90),
  ( 8, 5, 1, 2, 1249.00),
  ( 9, 5, 4, 2,   49.90),
  (10, 6, 7, 1,   39.90),
  (11, 7, 3, 1,   89.90),
  (12, 7, 4, 3,   44.90),
  (13, 8, 6, 1,  199.00),
  (14, 8, 7, 2,   39.90),
  (15, 8, 5, 1,  259.00);

-- Séquences : on aligne les compteurs sur les valeurs déjà insérées,
-- sinon un INSERT sans id échouerait en doublon de clé primaire.
DO $$
BEGIN
    PERFORM setval('categories_category_id_seq',     (SELECT MAX(category_id)   FROM categories));
    PERFORM setval('customers_customer_id_seq',      (SELECT MAX(customer_id)   FROM customers));
    PERFORM setval('products_product_id_seq',        (SELECT MAX(product_id)    FROM products));
    PERFORM setval('orders_order_id_seq',            (SELECT MAX(order_id)      FROM orders));
    PERFORM setval('order_items_order_item_id_seq',  (SELECT MAX(order_item_id) FROM order_items));
END $$;
-- ============================================================
--  Vues du cours, vues utilitaires et contrôles de chargement
-- ============================================================

-- ------------------------------------------------------------
-- Les deux vues DU COURS (chapitre 5.3), reproduites à l'identique.
-- Elles sont présentes dans la base fournie sur la plateforme —
-- les exercices 5.3 EX01/EX02 demandent de les (re)créer, et
-- l'EX03 s'appuie dessus.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vue_commande AS
SELECT o.order_id,
       o.customer_id,
       COUNT(oi.order_item_id)                    AS nb_lignes,
       ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_commande
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id;

COMMENT ON VIEW vue_commande IS
  'Vue du cours (5.3) : une ligne par commande, retour au grain commande après le fan-out.';

CREATE OR REPLACE VIEW vue_ca_client AS
SELECT o.customer_id,
       ROUND(SUM(oi.quantity * oi.unit_price), 2) AS ca_client
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.customer_id;

COMMENT ON VIEW vue_ca_client IS
  'Vue du cours (5.3) : CA par client. Les clients sans commande en sont ABSENTS (JOIN, pas LEFT JOIN).';

-- ------------------------------------------------------------
-- Vue typée : mêmes données, vraie DATE.
-- Sert à explorer les fonctions de date PostgreSQL (date_trunc,
-- EXTRACT, intervalles) sans toucher aux tables du cours.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW orders_typed AS
SELECT order_id,
       customer_id,
       order_date::date AS order_date,
       status,
       channel
FROM orders;

COMMENT ON VIEW orders_typed IS
  'orders avec order_date en DATE. Les tables du cours gardent le TEXT.';

-- ------------------------------------------------------------
-- Vue de démonstration du fan-out : à projeter en séance (4.2 / 4.3).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_fanout_demo AS
SELECT 'orders seule'            AS requete,
       COUNT(*)                  AS resultat,
       'le grain est la commande' AS lecture
FROM orders
UNION ALL
SELECT 'jointure avec order_items (COUNT *)',
       COUNT(*),
       'le grain est devenu la ligne de commande — surcomptage'
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
UNION ALL
SELECT 'jointure avec COUNT(DISTINCT)',
       COUNT(DISTINCT o.order_id),
       'retour au grain commande'
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id;

COMMENT ON VIEW v_fanout_demo IS
  'Le fan-out ShopFlow : 8 commandes, 15 lignes de commande.';

-- ------------------------------------------------------------
-- Contrôle de chargement : échoue bruyamment si les volumes, le
-- fan-out ou le CA ne correspondent pas à la base de référence.
-- ------------------------------------------------------------
DO $$
DECLARE
    n_cat INTEGER; n_cus INTEGER; n_pro INTEGER; n_ord INTEGER; n_itm INTEGER;
    n_fanout INTEGER; ca NUMERIC; n_sans_commande INTEGER;
BEGIN
    SELECT COUNT(*) INTO n_cat FROM categories;
    SELECT COUNT(*) INTO n_cus FROM customers;
    SELECT COUNT(*) INTO n_pro FROM products;
    SELECT COUNT(*) INTO n_ord FROM orders;
    SELECT COUNT(*) INTO n_itm FROM order_items;

    IF (n_cat, n_cus, n_pro, n_ord, n_itm) <> (5, 7, 8, 8, 15) THEN
        RAISE EXCEPTION
          'Chargement ShopFlow incorrect : % catégories / % clients / % produits / % commandes / % lignes (attendu 5/7/8/8/15)',
          n_cat, n_cus, n_pro, n_ord, n_itm;
    END IF;

    SELECT COUNT(*) INTO n_fanout
      FROM orders o JOIN order_items oi ON oi.order_id = o.order_id;

    SELECT ROUND(SUM(quantity * unit_price), 2) INTO ca FROM order_items;

    SELECT COUNT(*) INTO n_sans_commande
      FROM customers c
      WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

    IF (n_fanout, ca, n_sans_commande) <> (15, 6326.40, 1) THEN
        RAISE EXCEPTION
          'Contrôles ShopFlow incorrects : fan-out % / CA % / % client sans commande (attendu 15 / 6326.40 / 1)',
          n_fanout, ca, n_sans_commande;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '  ShopFlow chargé : % catégories, % clients, % produits, % commandes, % lignes',
                 n_cat, n_cus, n_pro, n_ord, n_itm;
    RAISE NOTICE '  Fan-out : % lignes pour % commandes — CA total %', n_fanout, n_ord, ca;
    RAISE NOTICE '  Anti-jointures : Gaël Morin (client sans commande), Grille-pain vintage (produit jamais commandé)';
    RAISE NOTICE '';
END $$;
