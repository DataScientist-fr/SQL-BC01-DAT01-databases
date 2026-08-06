-- ============================================================
--  CareAccess — schéma PostgreSQL
--  Portage du schéma SQLite du cours SQL BC01-DAT01-01
-- ============================================================
--
--  CHOIX DE CONCEPTION : scheduled_at et event_time restent en TEXT.
--
--  SQLite n'a pas de type date natif ; le cours stocke donc les
--  horodatages sous forme de chaînes 'YYYY-MM-DD HH:MM'. On conserve
--  ce typage pour que les 9 solutions du cours produisent EXACTEMENT
--  le même résultat ici et sur la plateforme.
--
--  Une vue `appointments_typed` (fichier 03-views.sql) expose les
--  mêmes données avec de vrais TIMESTAMP, pour explorer les fonctions
--  de date PostgreSQL sans casser la fidélité aux exercices.
-- ============================================================

DROP TABLE IF EXISTS appointment_events CASCADE;
DROP TABLE IF EXISTS appointments      CASCADE;
DROP TABLE IF EXISTS practitioners     CASCADE;
DROP TABLE IF EXISTS patients          CASCADE;

-- ------------------------------------------------------------
-- Grain : une ligne = un patient (entité)
-- ------------------------------------------------------------
CREATE TABLE patients (
    patient_id   SERIAL PRIMARY KEY,
    patient_name TEXT NOT NULL,
    birth_year   INTEGER,          -- nullable : Yann Le Goff (id 4)
    city         TEXT,             -- nullable : Sofia Rossi  (id 5)
    risk_level   TEXT              -- nullable : Amina Cherif (id 3)
);

COMMENT ON TABLE  patients            IS 'Grain : un patient. Table de référence (entité).';
COMMENT ON COLUMN patients.risk_level IS 'NULL = non évalué. Ce n''est PAS un risque faible.';

-- ------------------------------------------------------------
-- Grain : une ligne = un praticien (entité)
-- ------------------------------------------------------------
CREATE TABLE practitioners (
    practitioner_id   SERIAL PRIMARY KEY,
    practitioner_name TEXT NOT NULL,
    specialty         TEXT NOT NULL
);

COMMENT ON TABLE practitioners IS 'Grain : un praticien. Table de référence (entité).';

-- ------------------------------------------------------------
-- Grain : une ligne = un rendez-vous planifié (transactionnel)
-- Porte 2 FK -> côté « N » de deux relations 1-N
-- ------------------------------------------------------------
CREATE TABLE appointments (
    appointment_id   SERIAL PRIMARY KEY,
    patient_id       INTEGER NOT NULL REFERENCES patients(patient_id),
    practitioner_id  INTEGER NOT NULL REFERENCES practitioners(practitioner_id),
    scheduled_at     TEXT NOT NULL,   -- 'YYYY-MM-DD HH:MM' (cf. note en tête)
    status           TEXT NOT NULL,
    appointment_type TEXT NOT NULL
);

COMMENT ON TABLE appointments IS
  'Grain : un rendez-vous. 7 lignes. Joindre à appointment_events produit un fan-out (14 lignes).';

-- ------------------------------------------------------------
-- Grain : une ligne = un événement du cycle de vie d'un RDV
-- Table au grain le PLUS FIN -> source du fan-out
-- ------------------------------------------------------------
CREATE TABLE appointment_events (
    event_id       SERIAL PRIMARY KEY,
    appointment_id INTEGER NOT NULL REFERENCES appointments(appointment_id),
    event_type     TEXT NOT NULL,
    event_time     TEXT NOT NULL,
    actor          TEXT             -- nullable : événements générés par le système
);

COMMENT ON TABLE appointment_events IS
  'Grain : un événement. 14 lignes pour 7 rendez-vous. C''est la table qui provoque le fan-out.';

-- Index conformes à ce que ferait un vrai système transactionnel
CREATE INDEX idx_appointments_patient      ON appointments(patient_id);
CREATE INDEX idx_appointments_practitioner ON appointments(practitioner_id);
CREATE INDEX idx_events_appointment        ON appointment_events(appointment_id);
-- ============================================================
--  CareAccess — données de référence
--  Extrait de la base de test réelle de DataScientist.fr
--  (cours SQL BC01-DAT01-01, activités 4448 à 4463)
-- ============================================================

-- patients (6 lignes)
INSERT INTO patients (patient_id, patient_name, birth_year, city, risk_level) VALUES
  (1, 'Chloé Martin', 1992, 'Lille', 'low'),
  (2, 'Bruno Diallo', 1975, 'Lyon', 'high'),
  (3, 'Amina Cherif', 1988, 'Lille', NULL),
  (4, 'Yann Le Goff', NULL, 'Nantes', 'medium'),
  (5, 'Sofia Rossi', 1969, NULL, 'high'),
  (6, 'Karim Benali', 2001, 'Lyon', 'low');

-- practitioners (3 lignes)
INSERT INTO practitioners (practitioner_id, practitioner_name, specialty) VALUES
  (1, 'Dr. Lefevre', 'généraliste'),
  (2, 'Dr. Nguyen', 'cardiologie'),
  (3, 'Dr. Moreau', 'généraliste');

-- appointments (7 lignes)
INSERT INTO appointments (appointment_id, patient_id, practitioner_id, scheduled_at, status, appointment_type) VALUES
  (1, 1, 1, '2026-01-05 09:00', 'completed', 'consultation'),
  (2, 2, 2, '2026-01-05 10:30', 'completed', 'first_visit'),
  (3, 3, 1, '2026-01-06 14:00', 'scheduled', 'follow_up'),
  (4, 4, 3, '2026-01-06 15:00', 'cancelled', 'consultation'),
  (5, 5, 2, '2026-01-07 08:30', 'no_show', 'follow_up'),
  (6, 6, 1, '2026-01-07 11:00', 'scheduled', 'consultation'),
  (7, 1, 3, '2026-01-08 16:00', 'completed', 'follow_up');

-- appointment_events (14 lignes)
INSERT INTO appointment_events (event_id, appointment_id, event_type, event_time, actor) VALUES
  (1, 1, 'created', '2026-01-02 12:00', 'reception'),
  (2, 1, 'confirmed', '2026-01-03 09:15', 'patient'),
  (3, 1, 'checked_in', '2026-01-05 08:55', 'reception'),
  (4, 2, 'created', '2026-01-02 13:00', 'reception'),
  (5, 2, 'confirmed', '2026-01-04 10:00', 'patient'),
  (6, 3, 'created', '2026-01-04 09:00', NULL),
  (7, 4, 'created', '2026-01-05 09:00', 'reception'),
  (8, 4, 'cancelled', '2026-01-06 08:00', 'patient'),
  (9, 5, 'created', '2026-01-05 10:00', 'reception'),
  (10, 5, 'no_show', '2026-01-07 09:00', 'system'),
  (11, 6, 'created', '2026-01-06 10:00', 'reception'),
  (12, 7, 'created', '2026-01-05 10:00', 'reception'),
  (13, 7, 'confirmed', '2026-01-06 11:30', 'patient'),
  (14, 7, 'checked_in', '2026-01-08 15:50', 'reception');

-- Séquences : on aligne les compteurs sur les valeurs déjà insérées,
-- sinon un INSERT sans id échouerait en doublon de clé primaire.
-- (bloc DO plutôt que 4 SELECT : même effet, sans les tables de résultat
--  qui pollueraient la sortie de `make load`)
DO $$
BEGIN
    PERFORM setval('patients_patient_id_seq',           (SELECT MAX(patient_id)      FROM patients));
    PERFORM setval('practitioners_practitioner_id_seq', (SELECT MAX(practitioner_id) FROM practitioners));
    PERFORM setval('appointments_appointment_id_seq',   (SELECT MAX(appointment_id)  FROM appointments));
    PERFORM setval('appointment_events_event_id_seq',   (SELECT MAX(event_id)        FROM appointment_events));
END $$;
-- ============================================================
--  Vues utilitaires et contrôles de chargement
-- ============================================================

-- ------------------------------------------------------------
-- Vue typée : mêmes données, vrais TIMESTAMP.
-- Sert à explorer les fonctions de date PostgreSQL (date_trunc,
-- EXTRACT, intervalles) sans toucher aux tables du cours.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW appointments_typed AS
SELECT appointment_id,
       patient_id,
       practitioner_id,
       scheduled_at::timestamp AS scheduled_at,
       status,
       appointment_type
FROM appointments;

COMMENT ON VIEW appointments_typed IS
  'appointments avec scheduled_at en TIMESTAMP. Les tables du cours gardent le TEXT.';

-- ------------------------------------------------------------
-- Vue de démonstration du fan-out : à projeter en séance.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_fanout_demo AS
SELECT 'appointments seule'          AS requete,
       COUNT(*)                      AS resultat,
       'le grain est le rendez-vous' AS lecture
FROM appointments
UNION ALL
SELECT 'jointure avec events (COUNT *)',
       COUNT(*),
       'le grain est devenu l''événement — surcomptage'
FROM appointments a
JOIN appointment_events e ON e.appointment_id = a.appointment_id
UNION ALL
SELECT 'jointure avec COUNT(DISTINCT)',
       COUNT(DISTINCT a.appointment_id),
       'retour au grain rendez-vous'
FROM appointments a
JOIN appointment_events e ON e.appointment_id = a.appointment_id;

-- ------------------------------------------------------------
-- Contrôle de chargement : échoue bruyamment si les volumes
-- ne correspondent pas à la base de référence.
-- ------------------------------------------------------------
DO $$
DECLARE
    n_pat INTEGER; n_pra INTEGER; n_rdv INTEGER; n_evt INTEGER;
BEGIN
    SELECT COUNT(*) INTO n_pat FROM patients;
    SELECT COUNT(*) INTO n_pra FROM practitioners;
    SELECT COUNT(*) INTO n_rdv FROM appointments;
    SELECT COUNT(*) INTO n_evt FROM appointment_events;

    IF (n_pat, n_pra, n_rdv, n_evt) <> (6, 3, 7, 14) THEN
        RAISE EXCEPTION
          'Chargement CareAccess incorrect : % patients / % praticiens / % RDV / % événements (attendu 6/3/7/14)',
          n_pat, n_pra, n_rdv, n_evt;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '  CareAccess chargé : % patients, % praticiens, % rendez-vous, % événements',
                 n_pat, n_pra, n_rdv, n_evt;
    RAISE NOTICE '  NULL de référence : Amina Cherif (risk_level), Sofia Rossi (city), Yann Le Goff (birth_year)';
    RAISE NOTICE '';
END $$;
