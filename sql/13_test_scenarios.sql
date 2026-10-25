-- =====================================================================
-- Pharma-Trace | 13_test_scenarios.sql   (evaluation: tampering and counterfeit insertion)
-- Run as pharma_trace after 10_triggers.sql. Use "Run Script" (F5).
-- Each scenario says what you should see. Screenshot the results for the report.
-- =====================================================================
SET SERVEROUTPUT ON

-- S1 Valid transfer through the procedure, then verify the chain      -> VALID
EXEC sp_record_transfer(1, 5, 6, 500, 'TN-99-XX-0001')
SELECT fn_verify_chain(1) AS s1_chain FROM dual;

-- S2 Unauthorized seller (party 8 has an expired license)             -> ORA-20011
EXEC sp_record_transfer(2, 4, 8, 100)

-- S3 Oversell: sender holds far less than 99999                       -> ORA-20013
EXEC sp_record_transfer(1, 3, 5, 99999)

-- S4 Recalled batch cannot move                                       -> ORA-20012
EXEC sp_record_transfer(7, 1, 3, 100)

-- S5 Prescription drug without a prescription number                  -> ORA-20042
EXEC sp_dispense_unit('SN-MOX-B-0002', 6, 1, NULL)

-- S6 Tampering is blocked by the trigger                              -> ORA-20001
UPDATE custody_transfer SET quantity = 9999 WHERE transfer_id = 2;

-- S7 Tampering by an insider who switches the trigger off is still DETECTED
ALTER TRIGGER trg_custody_immutable DISABLE;
UPDATE custody_transfer SET quantity = 9999 WHERE transfer_id = 2;
SELECT fn_verify_chain(1) AS s7_after_tamper FROM dual;                 -- TAMPERED at seq 2
SELECT transfer_id, seq_no, hash_status, link_status FROM v_chain_verification WHERE batch_id = 1;
ROLLBACK;
ALTER TRIGGER trg_custody_immutable ENABLE;
SELECT fn_verify_chain(1) AS s7_after_rollback FROM dual;               -- VALID again

-- S8 Counterfeit insertion: a pack shows up at a pharmacy that never received the batch
INSERT INTO dispensing_record (unit_id, pharmacy_id, patient_id, prescription_ref)
VALUES (9, 10, 2, 'RX-FAKE-0001');                                       -- unit 9 is batch 5, pharmacy 10 never got it
EXEC sp_detect_counterfeits                                              -- ALERT BROKEN_CHAIN
SELECT alert_type, description FROM alert WHERE alert_status = 'OPEN' ORDER BY alert_id;
ROLLBACK;

-- S9 Cold chain: a warm reading for the vaccine creates an alert automatically
INSERT INTO storage_log (batch_id, party_id, recorded_at, temperature_c, humidity_pct)
VALUES (6, 10, SYSTIMESTAMP, 15.0, 45);
SELECT alert_type, description FROM alert WHERE alert_type = 'COLD_CHAIN' ORDER BY alert_id;
ROLLBACK;

-- S10 Audit trail of what happened in S1
SELECT table_name, operation, record_key, new_value, changed_by FROM audit_log ORDER BY audit_id;