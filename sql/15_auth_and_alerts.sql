-- =====================================================================
-- Pharma-Trace | 15_auth_and_alerts.sql   (run as pharma_trace, after 10_triggers.sql)
-- 1. Map Supabase login emails to roles   2. New TAMPER_ATTEMPT alert type
-- 3. Saved records can never be edited or deleted, and every attempt raises an alert for everyone
-- =====================================================================

-- 1. Emails: EDIT these six to the emails you create in Supabase (Authentication > Users)
ALTER TABLE user_account ADD (email VARCHAR2(100));
ALTER TABLE user_account ADD CONSTRAINT uq_user_email UNIQUE (email);

UPDATE user_account SET email = 'admin@pharmatrace.test',       is_active = 'Y' WHERE username = 'admin';
UPDATE user_account SET email = 'regulator@pharmatrace.test',   is_active = 'Y' WHERE username = 'regulator_cdsco';
UPDATE user_account SET email = 'auditor@pharmatrace.test',     is_active = 'Y' WHERE username = 'auditor_01';
UPDATE user_account SET email = 'manufacturer@pharmatrace.test', is_active = 'Y' WHERE username = 'mfr_sunpharma';
UPDATE user_account SET email = 'distributor@pharmatrace.test', is_active = 'Y' WHERE username = 'dist_apex';
UPDATE user_account SET email = 'pharmacy@pharmatrace.test',    is_active = 'Y' WHERE username = 'pharm_vellore';
COMMIT;

-- 2. Allow the new alert type
ALTER TABLE alert DROP CONSTRAINT ck_alert_type;
ALTER TABLE alert ADD CONSTRAINT ck_alert_type CHECK (alert_type IN
  ('DUPLICATE_SERIAL','BROKEN_CHAIN','UNAUTHORIZED_SELLER','IMPOSSIBLE_ROUTE','EXPIRED','RECALLED','COLD_CHAIN','TAMPER_ATTEMPT'));

-- 3. Logger that survives the rollback of the blocked statement (autonomous transaction)
CREATE OR REPLACE PROCEDURE sp_log_tamper(p_table VARCHAR2, p_op VARCHAR2, p_key VARCHAR2,
                                          p_batch NUMBER, p_old VARCHAR2, p_new VARCHAR2) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_who VARCHAR2(100) := NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), USER);
BEGIN
  INSERT INTO alert (alert_type, batch_id, description)
  VALUES ('TAMPER_ATTEMPT', p_batch,
          SUBSTR(v_who || ' tried to ' || LOWER(p_op) || ' a saved ' || p_table || ' record (id ' || p_key || '). The change was blocked.', 1, 300));
  INSERT INTO audit_log (table_name, operation, record_key, old_value, new_value, changed_by)
  VALUES (p_table, p_op, p_key, SUBSTR(p_old, 1, 500), SUBSTR(p_new, 1, 500), SUBSTR(v_who, 1, 30));
  COMMIT;
END sp_log_tamper;
/

-- Saved records are append-only: custody transfers, storage readings, dispensing records
CREATE OR REPLACE TRIGGER trg_custody_immutable
BEFORE UPDATE OR DELETE ON custody_transfer FOR EACH ROW
BEGIN
  sp_log_tamper('CUSTODY_TRANSFER', CASE WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END, TO_CHAR(:OLD.transfer_id), :OLD.batch_id,
                'qty=' || :OLD.quantity, CASE WHEN UPDATING THEN 'qty=' || :NEW.quantity END);
  RAISE_APPLICATION_ERROR(-20001, 'Saved records cannot be changed. The attempt was logged and an alert was raised for everyone.');
END;
/

CREATE OR REPLACE TRIGGER trg_storage_immutable
BEFORE UPDATE OR DELETE ON storage_log FOR EACH ROW
BEGIN
  sp_log_tamper('STORAGE_LOG', CASE WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END, TO_CHAR(:OLD.log_id), :OLD.batch_id,
                'temp=' || :OLD.temperature_c, CASE WHEN UPDATING THEN 'temp=' || :NEW.temperature_c END);
  RAISE_APPLICATION_ERROR(-20001, 'Saved records cannot be changed. The attempt was logged and an alert was raised for everyone.');
END;
/

CREATE OR REPLACE TRIGGER trg_dispense_immutable
BEFORE UPDATE OR DELETE ON dispensing_record FOR EACH ROW
BEGIN
  sp_log_tamper('DISPENSING_RECORD', CASE WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END, TO_CHAR(:OLD.dispense_id), NULL,
                'unit=' || :OLD.unit_id, CASE WHEN UPDATING THEN 'unit=' || :NEW.unit_id END);
  RAISE_APPLICATION_ERROR(-20001, 'Saved records cannot be changed. The attempt was logged and an alert was raised for everyone.');
END;
/

-- Test: both fail with ORA-20001, but the alert and audit rows are saved
UPDATE custody_transfer SET quantity = 9999 WHERE transfer_id = 1;
DELETE FROM storage_log WHERE log_id = 1;
SELECT alert_type, description FROM alert WHERE alert_type = 'TAMPER_ATTEMPT' ORDER BY alert_id;
SELECT table_name, operation, record_key, changed_by FROM audit_log WHERE operation IN ('UPDATE','DELETE') ORDER BY audit_id DESC;