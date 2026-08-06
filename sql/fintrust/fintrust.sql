-- ============================================================
--  FinTrust — schéma PostgreSQL
--  Portage du schéma SQLite du cours SQL BC01-DAT01-01
-- ============================================================
--
--  TROIS CHOIX DE CONCEPTION :
--
--  1. amount est en NUMERIC(12,2), pas en double precision.
--     La plateforme le stocke en REAL, mais les solutions du cours
--     écrivent ROUND(SUM(amount), 2) — et PostgreSQL n'a PAS de
--     round(double precision, integer) : la requête échouerait.
--     NUMERIC fait passer les solutions telles quelles, et supprime
--     au passage les arrondis flottants de SQLite.
--
--  2. opened_at et transaction_date restent en TEXT.
--     SQLite n'a pas de type date ; le cours stocke 'YYYY-MM-DD'.
--     Même arbitrage que scheduled_at dans CareAccess, pour que les
--     solutions produisent EXACTEMENT le même résultat qu'en ligne.
--     La vue `transactions_typed` expose la vraie DATE.
--
--  3. merchant_id est nullable : NULL = virement interne, sans
--     commerçant. C'est ce qui donne du sens aux LEFT JOIN du cours.
--
--  LE POINT PÉDAGOGIQUE DE CETTE BASE : amount est SIGNÉ (négatif =
--  débit). SUM(amount) donne le solde net, pas le volume échangé.
--  Voir la vue v_signed_amounts_demo (leçon 2.1 « Granularité,
--  fan-out & montants signés »).
-- ============================================================

DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS merchants    CASCADE;
DROP TABLE IF EXISTS accounts     CASCADE;

-- ------------------------------------------------------------
-- Grain : une ligne = un compte bancaire (entité)
-- ------------------------------------------------------------
CREATE TABLE accounts (
    account_id    SERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    account_type  TEXT NOT NULL,   -- courant / épargne
    opened_at     TEXT NOT NULL    -- 'YYYY-MM-DD' (cf. note en tête)
);

COMMENT ON TABLE accounts IS 'Grain : un compte. Table de référence (entité).';

-- ------------------------------------------------------------
-- Grain : une ligne = un commerçant (entité)
-- ------------------------------------------------------------
CREATE TABLE merchants (
    merchant_id   SERIAL PRIMARY KEY,
    merchant_name TEXT NOT NULL,
    category      TEXT NOT NULL
);

COMMENT ON TABLE merchants IS 'Grain : un commerçant. Table de référence (entité).';

-- ------------------------------------------------------------
-- Grain : une ligne = une transaction (transactionnel)
-- ------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id   SERIAL PRIMARY KEY,
    account_id       INTEGER NOT NULL REFERENCES accounts(account_id),
    merchant_id      INTEGER REFERENCES merchants(merchant_id),  -- nullable : virement interne
    amount           NUMERIC(12,2) NOT NULL,  -- SIGNÉ (cf. note en tête)
    transaction_type TEXT NOT NULL,           -- debit / credit / transfer
    transaction_date TEXT NOT NULL,           -- 'YYYY-MM-DD'
    status           TEXT NOT NULL            -- completed / pending / failed
);

COMMENT ON TABLE  transactions            IS
  'Grain : une transaction. 10 lignes. amount est signé : SUM donne le net, pas le volume.';
COMMENT ON COLUMN transactions.amount     IS 'Négatif = débit, positif = crédit.';
COMMENT ON COLUMN transactions.merchant_id IS 'NULL = virement interne, pas de commerçant.';

-- Index conformes à ce que ferait un vrai système transactionnel
CREATE INDEX idx_transactions_account  ON transactions(account_id);
CREATE INDEX idx_transactions_merchant ON transactions(merchant_id);
-- ============================================================
--  FinTrust — données de référence
--  Extrait de la base de test réelle de DataScientist.fr
--  (cours SQL BC01-DAT01-01, activités 4467, 4472, 4485)
-- ============================================================

-- accounts (3 lignes)
INSERT INTO accounts (account_id, customer_name, account_type, opened_at) VALUES
  (1, 'Alice Durand', 'courant', '2024-11-02'),
  (2, 'Bruno Lefef',  'courant', '2025-01-15'),
  (3, 'Chen Wei',     'épargne', '2025-02-20');

-- merchants (4 lignes)
INSERT INTO merchants (merchant_id, merchant_name, category) VALUES
  (1, 'SuperMarché Centre', 'alimentation'),
  (2, 'TransConnect',       'transport'),
  (3, 'ElectroPlus',        'high-tech'),
  (4, 'CaféVoltaire',       'restauration');

-- transactions (10 lignes)
-- Les deux lignes 8 et 9 sont les deux faces d'un même virement interne :
-- -300 puis +300, sans commerçant. Elles s'annulent dans SUM(amount).
INSERT INTO transactions (transaction_id, account_id, merchant_id, amount, transaction_type, transaction_date, status) VALUES
  ( 1, 1, NULL,  2500.00, 'credit',   '2025-06-01', 'completed'),
  ( 2, 1, 1,      -82.40, 'debit',    '2025-06-03', 'completed'),
  ( 3, 1, 4,      -12.50, 'debit',    '2025-06-04', 'completed'),
  ( 4, 1, 3,     -499.00, 'debit',    '2025-06-06', 'completed'),
  ( 5, 2, NULL,  1800.00, 'credit',   '2025-06-01', 'completed'),
  ( 6, 2, 2,      -55.00, 'debit',    '2025-06-05', 'completed'),
  ( 7, 2, 1,     -120.30, 'debit',    '2025-06-07', 'pending'),
  ( 8, 3, NULL,  -300.00, 'transfer', '2025-06-02', 'completed'),
  ( 9, 3, NULL,   300.00, 'transfer', '2025-06-02', 'completed'),
  (10, 3, 3,      -89.90, 'debit',    '2025-06-08', 'failed');

-- Séquences : on aligne les compteurs sur les valeurs déjà insérées,
-- sinon un INSERT sans id échouerait en doublon de clé primaire.
DO $$
BEGIN
    PERFORM setval('accounts_account_id_seq',         (SELECT MAX(account_id)     FROM accounts));
    PERFORM setval('merchants_merchant_id_seq',       (SELECT MAX(merchant_id)    FROM merchants));
    PERFORM setval('transactions_transaction_id_seq', (SELECT MAX(transaction_id) FROM transactions));
END $$;
-- ============================================================
--  Vues utilitaires et contrôles de chargement
-- ============================================================

-- ------------------------------------------------------------
-- Vue typée : mêmes données, vraie DATE.
-- Sert à explorer les fonctions de date PostgreSQL (date_trunc,
-- EXTRACT, intervalles) sans toucher aux tables du cours.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW transactions_typed AS
SELECT transaction_id,
       account_id,
       merchant_id,
       amount,
       transaction_type,
       transaction_date::date AS transaction_date,
       status
FROM transactions;

COMMENT ON VIEW transactions_typed IS
  'transactions avec transaction_date en DATE. Les tables du cours gardent le TEXT.';

-- ------------------------------------------------------------
-- Vue de démonstration des montants signés : à projeter en séance.
-- Trois lectures du même SUM, sur les seules transactions abouties.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_signed_amounts_demo AS
SELECT 'SUM(amount) brut'                   AS requete,
       SUM(amount)                          AS resultat,
       'le solde net — les débits annulent les crédits' AS lecture
FROM transactions WHERE status = 'completed'
UNION ALL
SELECT 'crédits seuls',
       SUM(amount) FILTER (WHERE amount > 0),
       'ce qui est entré'
FROM transactions WHERE status = 'completed'
UNION ALL
SELECT 'débits seuls',
       SUM(amount) FILTER (WHERE amount < 0),
       'ce qui est sorti (négatif)'
FROM transactions WHERE status = 'completed'
UNION ALL
SELECT 'volume échangé',
       SUM(ABS(amount)),
       'la vraie activité — ni le net ni les crédits'
FROM transactions WHERE status = 'completed';

COMMENT ON VIEW v_signed_amounts_demo IS
  'Le piège des montants signés : SUM(amount) donne le net, pas le volume.';

-- ------------------------------------------------------------
-- Contrôle de chargement : échoue bruyamment si les volumes ou les
-- totaux ne correspondent pas à la base de référence.
-- ------------------------------------------------------------
DO $$
DECLARE
    n_acc INTEGER; n_mer INTEGER; n_tx INTEGER;
    credits NUMERIC; debits NUMERIC; net NUMERIC;
BEGIN
    SELECT COUNT(*) INTO n_acc FROM accounts;
    SELECT COUNT(*) INTO n_mer FROM merchants;
    SELECT COUNT(*) INTO n_tx  FROM transactions;

    IF (n_acc, n_mer, n_tx) <> (3, 4, 10) THEN
        RAISE EXCEPTION
          'Chargement FinTrust incorrect : % comptes / % commerçants / % transactions (attendu 3/4/10)',
          n_acc, n_mer, n_tx;
    END IF;

    SELECT SUM(amount) FILTER (WHERE amount > 0),
           SUM(amount) FILTER (WHERE amount < 0),
           SUM(amount)
      INTO credits, debits, net
      FROM transactions WHERE status = 'completed';

    IF (credits, debits, net) <> (4600.00, -948.90, 3651.10) THEN
        RAISE EXCEPTION
          'Totaux FinTrust incorrects : crédits % / débits % / net % (attendu 4600.00 / -948.90 / 3651.10)',
          credits, debits, net;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '  FinTrust chargé : % comptes, % commerçants, % transactions', n_acc, n_mer, n_tx;
    RAISE NOTICE '  Statut completed : crédits %, débits %, net %', credits, debits, net;
    RAISE NOTICE '  NULL de référence : merchant_id des virements internes (tx 1, 5, 8, 9)';
    RAISE NOTICE '';
END $$;
