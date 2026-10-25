-- =====================================================================
-- Pharma-Trace | Review 2 | 10_triggers.sql   (Oracle PL/SQL)
-- Run AFTER 09_cursors.sql (needs fn_calc_hash). Use "Run Script" (F5).
-- After this, the tamper demo in 04_single_row_functions.sql is BLOCKED (ORA-20001).
-- =====================================================================

-- 1. Custody records are append-only
CREATE OR REPLACE TRIGGER trg_custody_immutable
BEFORE UPDATE OR DELETE ON custody_transfer
BEGIN
  RAISE_APPLICATION_ERROR(-20001, 'custody_transfer is append-only: UPDATE and DELETE are not allowed');
END;
/

-- 2. A new custody record must carry a correct hash and a movable batch
CREATE OR REPLACE TRIGGER trg_custody_guard
BEFORE INSERT ON custody_transfer
FOR EACH ROW
DECLARE
  v_status batch.batch_status%TYPE;
  v_expiry batch.expiry_date%TYPE;
BEGIN
  SELECT batch_status, expiry_date INTO v_status, v_expiry FROM batch WHERE batch_id = :NEW.batch_id;
  IF v_status <> 'ACTIVE' OR v_expiry < SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20003, 'Batch is ' || v_status || ' or expired: transfer blocked');
  END IF;
  IF :NEW.current_hash <> fn_calc_hash(:NEW.batch_id, :NEW.shipment_id, :NEW.seq_no, :NEW.quantity, :NEW.previous_hash) THEN
    RAISE_APPLICATION_ERROR(-20002, 'current_hash does not match the record contents');
  END IF;
END;
/

-- 3. Dispensing rules: usable batch, unflagged pack, prescription when required
CREATE OR REPLACE TRIGGER trg_dispense_guard
BEFORE INSERT ON dispensing_record
FOR EACH ROW
DECLARE
  v_ustat drug_unit.unit_status%TYPE; v_bstat batch.batch_status%TYPE;
  v_exp   batch.expiry_date%TYPE;     v_rx    drug.requires_prescription%TYPE;
BEGIN
  SELECT du.unit_status, b.batch_status, b.expiry_date, d.requires_prescription
  INTO   v_ustat, v_bstat, v_exp, v_rx
  FROM   drug_unit du JOIN batch b ON b.batch_id = du.batch_id JOIN drug d ON d.drug_id = b.drug_id
  WHERE  du.unit_id = :NEW.unit_id;
  IF v_ustat = 'FLAGGED' THEN RAISE_APPLICATION_ERROR(-20040, 'Flagged pack cannot be dispensed'); END IF;
  IF v_bstat IN ('RECALLED', 'QUARANTINED', 'EXPIRED') OR v_exp < :NEW.dispense_date THEN
    RAISE_APPLICATION_ERROR(-20041, 'Batch is ' || v_bstat || ' or expired: dispensing blocked');
  END IF;
  IF v_rx = 'Y' AND :NEW.prescription_ref IS NULL THEN
    RAISE_APPLICATION_ERROR(-20042, 'Prescription reference required for this drug');
  END IF;
END;
/

-- 4. Mark the pack as dispensed
CREATE OR REPLACE TRIGGER trg_dispense_mark
AFTER INSERT ON dispensing_record
FOR EACH ROW
BEGIN
  UPDATE drug_unit SET unit_status = 'DISPENSED' WHERE unit_id = :NEW.unit_id;
END;
/

-- 5. Cold chain: a reading outside the drug's range raises an alert
CREATE OR REPLACE TRIGGER trg_storage_coldchain
AFTER INSERT ON storage_log
FOR EACH ROW
DECLARE
  v_min drug.min_storage_temp%TYPE; v_max drug.max_storage_temp%TYPE;
BEGIN
  SELECT d.min_storage_temp, d.max_storage_temp INTO v_min, v_max
  FROM   batch b JOIN drug d ON d.drug_id = b.drug_id WHERE b.batch_id = :NEW.batch_id;
  IF :NEW.temperature_c < v_min OR :NEW.temperature_c > v_max THEN
    INSERT INTO alert (alert_type, batch_id, description)
    VALUES ('COLD_CHAIN', :NEW.batch_id, 'Temperature ' || :NEW.temperature_c || ' C outside ' || v_min || ' to ' || v_max || ' C');
  END IF;
END;
/

-- 6. Audit trail for the important tables
CREATE OR REPLACE TRIGGER trg_audit_batch
AFTER INSERT OR UPDATE OR DELETE ON batch FOR EACH ROW
DECLARE v_op VARCHAR2(6);
BEGIN
  v_op := CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END;
  INSERT INTO audit_log (table_name, operation, record_key, old_value, new_value)
  VALUES ('BATCH', v_op, TO_CHAR(NVL(:NEW.batch_id, :OLD.batch_id)),
          CASE WHEN v_op = 'INSERT' THEN NULL ELSE 'status=' || :OLD.batch_status END,
          CASE WHEN v_op = 'DELETE' THEN NULL ELSE 'status=' || :NEW.batch_status END);
END;
/

CREATE OR REPLACE TRIGGER trg_audit_party
AFTER INSERT OR UPDATE OR DELETE ON party FOR EACH ROW
DECLARE v_op VARCHAR2(6);
BEGIN
  v_op := CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END;
  INSERT INTO audit_log (table_name, operation, record_key, old_value, new_value)
  VALUES ('PARTY', v_op, TO_CHAR(NVL(:NEW.party_id, :OLD.party_id)),
          CASE WHEN v_op = 'INSERT' THEN NULL ELSE 'license=' || :OLD.license_status END,
          CASE WHEN v_op = 'DELETE' THEN NULL ELSE 'license=' || :NEW.license_status END);
END;
/

CREATE OR REPLACE TRIGGER trg_audit_custody
AFTER INSERT ON custody_transfer FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, operation, record_key, new_value)
  VALUES ('CUSTODY_TRANSFER', 'INSERT', TO_CHAR(:NEW.transfer_id),
          'batch=' || :NEW.batch_id || ' seq=' || :NEW.seq_no || ' qty=' || :NEW.quantity);
END;
/

CREATE OR REPLACE TRIGGER trg_audit_dispense
AFTER INSERT ON dispensing_record FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, operation, record_key, new_value)
  VALUES ('DISPENSING_RECORD', 'INSERT', TO_CHAR(:NEW.dispense_id),
          'unit=' || :NEW.unit_id || ' pharmacy=' || :NEW.pharmacy_id);
END;
/

-- ------------------------------ try them -----------------------------
-- Expected: ORA-20001 (tampering blocked)
UPDATE custody_transfer SET quantity = 9999 WHERE transfer_id = 1;
-- Expected: ORA-20001 (delete blocked)
DELETE FROM custody_transfer WHERE transfer_id = 1;
SELECT trigger_name, status FROM user_triggers ORDER BY trigger_name;