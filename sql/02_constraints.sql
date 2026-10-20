-- =====================================================================
-- Pharma-Trace | Review 1 | 02_constraints.sql   (Oracle 12c or later)
-- Run AFTER 01_ddl.sql.
-- PRIMARY KEY, NOT NULL and DEFAULT were already defined in 01_ddl.sql.
-- This script adds: UNIQUE, FOREIGN KEY, CHECK (all named constraints).
-- =====================================================================

-- ------------------------------ UNIQUE -------------------------------

ALTER TABLE party             ADD CONSTRAINT uq_party_license   UNIQUE (license_no);
ALTER TABLE party             ADD CONSTRAINT uq_party_email     UNIQUE (email);
ALTER TABLE drug              ADD CONSTRAINT uq_drug_candidate  UNIQUE (drug_name, strength, dosage_form);
ALTER TABLE batch             ADD CONSTRAINT uq_batch_mfr_no    UNIQUE (manufacturer_id, batch_no);
ALTER TABLE drug_unit         ADD CONSTRAINT uq_unit_serial     UNIQUE (serial_no);
ALTER TABLE custody_transfer  ADD CONSTRAINT uq_ct_batch_seq    UNIQUE (batch_id, seq_no);
ALTER TABLE custody_transfer  ADD CONSTRAINT uq_ct_current_hash UNIQUE (current_hash);
ALTER TABLE dispensing_record ADD CONSTRAINT uq_disp_unit       UNIQUE (unit_id);
ALTER TABLE user_account      ADD CONSTRAINT uq_user_username   UNIQUE (username);

-- ---------------------------- FOREIGN KEY ----------------------------
-- Default behaviour is "no action" (a parent row cannot be deleted while
-- children exist). History tables (custody_transfer, audit_log) never cascade.

ALTER TABLE batch ADD CONSTRAINT fk_batch_drug
    FOREIGN KEY (drug_id) REFERENCES drug (drug_id);
ALTER TABLE batch ADD CONSTRAINT fk_batch_manufacturer
    FOREIGN KEY (manufacturer_id) REFERENCES party (party_id);

ALTER TABLE drug_unit ADD CONSTRAINT fk_unit_batch
    FOREIGN KEY (batch_id) REFERENCES batch (batch_id);

ALTER TABLE shipment ADD CONSTRAINT fk_ship_from
    FOREIGN KEY (from_party_id) REFERENCES party (party_id);
ALTER TABLE shipment ADD CONSTRAINT fk_ship_to
    FOREIGN KEY (to_party_id) REFERENCES party (party_id);

ALTER TABLE custody_transfer ADD CONSTRAINT fk_ct_batch
    FOREIGN KEY (batch_id) REFERENCES batch (batch_id);
ALTER TABLE custody_transfer ADD CONSTRAINT fk_ct_shipment
    FOREIGN KEY (shipment_id) REFERENCES shipment (shipment_id);

ALTER TABLE storage_log ADD CONSTRAINT fk_log_batch
    FOREIGN KEY (batch_id) REFERENCES batch (batch_id);
ALTER TABLE storage_log ADD CONSTRAINT fk_log_party
    FOREIGN KEY (party_id) REFERENCES party (party_id);
ALTER TABLE storage_log ADD CONSTRAINT fk_log_shipment
    FOREIGN KEY (shipment_id) REFERENCES shipment (shipment_id) ON DELETE SET NULL;

ALTER TABLE dispensing_record ADD CONSTRAINT fk_disp_unit
    FOREIGN KEY (unit_id) REFERENCES drug_unit (unit_id);
ALTER TABLE dispensing_record ADD CONSTRAINT fk_disp_pharmacy
    FOREIGN KEY (pharmacy_id) REFERENCES party (party_id);
ALTER TABLE dispensing_record ADD CONSTRAINT fk_disp_patient
    FOREIGN KEY (patient_id) REFERENCES patient (patient_id);

ALTER TABLE alert ADD CONSTRAINT fk_alert_batch
    FOREIGN KEY (batch_id) REFERENCES batch (batch_id);
ALTER TABLE alert ADD CONSTRAINT fk_alert_unit
    FOREIGN KEY (unit_id) REFERENCES drug_unit (unit_id);

ALTER TABLE user_account ADD CONSTRAINT fk_user_party
    FOREIGN KEY (party_id) REFERENCES party (party_id) ON DELETE SET NULL;

-- -------------------------------- CHECK ------------------------------

ALTER TABLE party ADD CONSTRAINT ck_party_type
    CHECK (party_type IN ('MANUFACTURER','DISTRIBUTOR','WHOLESALER','PHARMACY','HOSPITAL'));
ALTER TABLE party ADD CONSTRAINT ck_party_license_status
    CHECK (license_status IN ('ACTIVE','EXPIRED','REVOKED'));

ALTER TABLE drug ADD CONSTRAINT ck_drug_rx
    CHECK (requires_prescription IN ('Y','N'));
ALTER TABLE drug ADD CONSTRAINT ck_drug_temp_range
    CHECK (min_storage_temp < max_storage_temp);

ALTER TABLE batch ADD CONSTRAINT ck_batch_dates
    CHECK (expiry_date > mfg_date);
ALTER TABLE batch ADD CONSTRAINT ck_batch_qty
    CHECK (quantity_produced > 0);
ALTER TABLE batch ADD CONSTRAINT ck_batch_status
    CHECK (batch_status IN ('ACTIVE','RECALLED','QUARANTINED','EXPIRED'));

ALTER TABLE drug_unit ADD CONSTRAINT ck_unit_status
    CHECK (unit_status IN ('IN_STOCK','DISPENSED','FLAGGED'));

ALTER TABLE shipment ADD CONSTRAINT ck_ship_parties_differ
    CHECK (from_party_id <> to_party_id);
ALTER TABLE shipment ADD CONSTRAINT ck_ship_dates
    CHECK (receive_date >= dispatch_date);
ALTER TABLE shipment ADD CONSTRAINT ck_ship_status
    CHECK (shipment_status IN ('IN_TRANSIT','DELIVERED','REJECTED'));

ALTER TABLE custody_transfer ADD CONSTRAINT ck_ct_qty
    CHECK (quantity > 0);
ALTER TABLE custody_transfer ADD CONSTRAINT ck_ct_seq
    CHECK (seq_no >= 1);
ALTER TABLE custody_transfer ADD CONSTRAINT ck_ct_hash_len
    CHECK (LENGTH(previous_hash) = 64 AND LENGTH(current_hash) = 64);

ALTER TABLE storage_log ADD CONSTRAINT ck_log_humidity
    CHECK (humidity_pct BETWEEN 0 AND 100);

ALTER TABLE patient ADD CONSTRAINT ck_patient_gender
    CHECK (gender IN ('M','F','O'));

ALTER TABLE alert ADD CONSTRAINT ck_alert_type
    CHECK (alert_type IN ('DUPLICATE_SERIAL','BROKEN_CHAIN','UNAUTHORIZED_SELLER',
                          'IMPOSSIBLE_ROUTE','EXPIRED','RECALLED','COLD_CHAIN'));
ALTER TABLE alert ADD CONSTRAINT ck_alert_status
    CHECK (alert_status IN ('OPEN','RESOLVED'));
ALTER TABLE alert ADD CONSTRAINT ck_alert_target
    CHECK (batch_id IS NOT NULL OR unit_id IS NOT NULL);

ALTER TABLE user_account ADD CONSTRAINT ck_user_role
    CHECK (role_name IN ('ADMIN','MANUFACTURER','DISTRIBUTOR','PHARMACY','REGULATOR','AUDITOR'));
ALTER TABLE user_account ADD CONSTRAINT ck_user_active
    CHECK (is_active IN ('Y','N'));

ALTER TABLE audit_log ADD CONSTRAINT ck_audit_operation
    CHECK (operation IN ('INSERT','UPDATE','DELETE'));

-- ------------------ MANAGING CONSTRAINTS (ALTER demos) ---------------

ALTER TABLE party DISABLE CONSTRAINT ck_party_license_status;
ALTER TABLE party ENABLE  CONSTRAINT ck_party_license_status;

ALTER TABLE patient ADD CONSTRAINT ck_patient_phone_len CHECK (LENGTH(phone) >= 10);
ALTER TABLE patient DROP CONSTRAINT ck_patient_phone_len;

ALTER TABLE party RENAME CONSTRAINT uq_party_email TO uq_party_email_addr;
ALTER TABLE party RENAME CONSTRAINT uq_party_email_addr TO uq_party_email;

-- ---------- CONSTRAINT TESTS (each marked line should fail) ----------
-- Run with "Run Script" (F5) in SQL Developer so execution continues after errors.
-- Take screenshots of the error messages for your report.

INSERT INTO party (party_name, party_type, license_no, license_expiry)
VALUES ('Test Co', 'ALIEN', 'L-001', DATE '2030-01-01');            -- ORA-02290 check violated

INSERT INTO party (party_name, party_type, license_no, license_expiry)
VALUES (NULL, 'PHARMACY', 'L-001', DATE '2030-01-01');              -- ORA-01400 cannot insert NULL

INSERT INTO party (party_name, party_type, license_no, license_expiry)
VALUES ('Alpha Pharmacy', 'PHARMACY', 'L-001', DATE '2030-01-01');  -- succeeds

INSERT INTO party (party_name, party_type, license_no, license_expiry)
VALUES ('Beta Pharmacy', 'PHARMACY', 'L-001', DATE '2030-01-01');   -- ORA-00001 unique violated

INSERT INTO batch (batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
VALUES ('B-TEST', 999, 999, DATE '2026-01-01', DATE '2028-01-01', 100);  -- ORA-02291 parent key not found

ROLLBACK;

-- ------------------------------ VERIFY -------------------------------

SELECT constraint_type, COUNT(*) AS total
FROM   user_constraints
GROUP  BY constraint_type
ORDER  BY constraint_type;      -- P = primary, U = unique, R = foreign, C = check/not null

SELECT table_name, constraint_name, r_constraint_name, delete_rule
FROM   user_constraints
WHERE  constraint_type = 'R'
ORDER  BY table_name, constraint_name;

SELECT table_name, constraint_name, search_condition
FROM   user_constraints
WHERE  constraint_type = 'C' AND constraint_name LIKE 'CK\_%' ESCAPE '\'
ORDER  BY table_name, constraint_name;