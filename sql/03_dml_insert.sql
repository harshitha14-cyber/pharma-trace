-- =====================================================================
-- Pharma-Trace | Review 1 | 03_dml_insert.sql   (Oracle 12c or later)
-- Run order: 00_drop_all.sql (optional) -> 01_ddl.sql -> 02_constraints.sql -> this file.
-- Part A: INSERT sample data (parents first, children after)
-- Part B: UPDATE demonstrations
-- Part C: DELETE demonstrations
-- Part D: Verify, then re-sync identity columns
--
-- All IDs are given explicitly so foreign keys line up. Run with
-- "Run Script" (F5) in SQL Developer so it continues after the planned errors.
--
-- Hash rule used for custody_transfer (reuse it in Review 2 verification):
--   current_hash = SHA-256( batch_id|shipment_id|seq_no|quantity|previous_hash )
--   previous_hash of seq_no 1 = genesis = 64 zeros
-- =====================================================================

-- ------------------------------ PART A: INSERT -----------------------

-- PARTY: single-row INSERTs with a column list (license_status uses its DEFAULT)
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (1, 'Sun Pharma Industries Ltd', 'MANUFACTURER', 'MFG-TN-1001', DATE '2029-03-31', 'Chennai', 'Tamil Nadu', 'contact@sunpharma.example', '+919841000001');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (2, 'Cipla Healthcare', 'MANUFACTURER', 'MFG-MH-1002', DATE '2029-06-30', 'Mumbai', 'Maharashtra', 'contact@ciplahc.example', '+919820000002');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (3, 'Apex Pharma Distributors', 'DISTRIBUTOR', 'DST-TN-2001', DATE '2028-12-31', 'Coimbatore', 'Tamil Nadu', 'sales@apexpharma.example', '+919842000003');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (4, 'MedLine Wholesale Traders', 'WHOLESALER', 'WHL-KA-3001', DATE '2028-09-30', 'Bengaluru', 'Karnataka', 'orders@medline.example', '+919880000004');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (5, 'Vellore Care Pharmacy', 'PHARMACY', 'PHR-TN-4001', DATE '2028-03-31', 'Vellore', 'Tamil Nadu', 'care@vellorepharmacy.example', '+919443000005');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (6, 'Anna Nagar Medicals', 'PHARMACY', 'PHR-TN-4002', DATE '2028-05-31', 'Chennai', 'Tamil Nadu', 'info@annanagarmed.example', '+919444000006');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (7, 'City General Hospital', 'HOSPITAL', 'HSP-TN-5001', DATE '2029-01-31', 'Vellore', 'Tamil Nadu', 'pharmacy@citygeneral.example', '+919445000007');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, license_status, city, state, email, phone)
VALUES (8, 'QuickMeds Traders', 'WHOLESALER', 'WHL-DL-3002', DATE '2025-12-31', 'EXPIRED', 'Delhi', 'Delhi', 'hello@quickmeds.example', '+911100000008');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, license_status, city, state, email, phone)
VALUES (9, 'ShadyRx Supplies', 'DISTRIBUTOR', 'DST-XX-2099', DATE '2024-06-30', 'REVOKED', 'Hyderabad', 'Telangana', 'trade@shadyrx.example', '+919100000009');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES (10, 'Green Cross Pharmacy', 'PHARMACY', 'PHR-KA-4003', DATE '2028-11-30', 'Bengaluru', 'Karnataka', 'help@greencross.example', '+919886000010');

-- DRUG: multi-row INSERT ALL
INSERT ALL
  INTO drug (drug_id, drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
       VALUES (1, 'Dolo 500', 'Paracetamol', 'TABLET', '500 mg', 'N', 15, 30)
  INTO drug (drug_id, drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
       VALUES (2, 'Mox 250', 'Amoxicillin', 'CAPSULE', '250 mg', 'Y', 15, 25)
  INTO drug (drug_id, drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
       VALUES (3, 'Lantus', 'Insulin glargine', 'INJECTION', '100 IU/ml', 'Y', 2, 8)
  INTO drug (drug_id, drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
       VALUES (4, 'Cetzine', 'Cetirizine', 'TABLET', '10 mg', 'N', 15, 30)
  INTO drug (drug_id, drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
       VALUES (5, 'Azithral 500', 'Azithromycin', 'TABLET', '500 mg', 'Y', 15, 30)
  INTO drug (drug_id, drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
       VALUES (6, 'Rabipur', 'Rabies vaccine', 'INJECTION', '2.5 IU', 'Y', 2, 8)
SELECT * FROM dual;

-- PATIENT
INSERT ALL
  INTO patient (patient_id, patient_name, dob, gender, phone) VALUES (1, 'Ravi Kumar',   DATE '1985-04-12', 'M', '9841011111')
  INTO patient (patient_id, patient_name, dob, gender, phone) VALUES (2, 'Priya Sharma', DATE '1992-09-03', 'F', '9841022222')
  INTO patient (patient_id, patient_name, dob, gender, phone) VALUES (3, 'Arun Prakash', DATE '1978-01-25', 'M', '9443033333')
  INTO patient (patient_id, patient_name, dob, gender, phone) VALUES (4, 'Meena Iyer',   DATE '2001-11-18', 'F', '9444044444')
  INTO patient (patient_id, patient_name, dob, gender, phone) VALUES (5, 'Karthik Raj',  DATE '1999-07-07', 'M', '9886055555')
SELECT * FROM dual;

-- BATCH (batch 4 is inserted as ACTIVE on purpose: Part B marks it EXPIRED with an UPDATE)
INSERT ALL
  INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
       VALUES (1, 'DOLO-2026-A', 1, 1, DATE '2026-01-10', DATE '2028-01-09', 10000)
  INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
       VALUES (2, 'MOX-2026-B',  2, 1, DATE '2026-02-15', DATE '2028-02-14', 5000)
  INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
       VALUES (3, 'LAN-2026-C',  3, 2, DATE '2026-03-01', DATE '2027-02-28', 2000)
  INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
       VALUES (4, 'CET-2025-D',  4, 2, DATE '2025-06-01', DATE '2026-06-01', 3000)
  INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
       VALUES (5, 'AZI-2026-E',  5, 1, DATE '2026-04-20', DATE '2028-04-19', 4000)
  INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
       VALUES (6, 'RAB-2026-F',  6, 2, DATE '2026-05-05', DATE '2027-05-04', 1500)
SELECT * FROM dual;

INSERT INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced, batch_status)
VALUES (7, 'DOLO-2026-G', 1, 1, DATE '2026-06-01', DATE '2028-05-31', 8000, 'RECALLED');
INSERT INTO batch (batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced, batch_status)
VALUES (8, 'MOX-2025-H', 2, 1, DATE '2025-09-01', DATE '2027-08-31', 2500, 'QUARANTINED');

-- DRUG_UNIT (serial numbers)
INSERT ALL
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (1,  'SN-DOLO-A-0001', 1, 'DISPENSED')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (2,  'SN-DOLO-A-0002', 1, 'IN_STOCK')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (3,  'SN-DOLO-A-0003', 1, 'IN_STOCK')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (4,  'SN-MOX-B-0001',  2, 'DISPENSED')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (5,  'SN-MOX-B-0002',  2, 'IN_STOCK')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (6,  'SN-LAN-C-0001',  3, 'DISPENSED')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (7,  'SN-LAN-C-0002',  3, 'IN_STOCK')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (8,  'SN-AZI-E-0001',  5, 'DISPENSED')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (9,  'SN-AZI-E-0002',  5, 'IN_STOCK')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (10, 'SN-RAB-F-0001',  6, 'DISPENSED')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (11, 'SN-RAB-F-0002',  6, 'IN_STOCK')
  INTO drug_unit (unit_id, serial_no, batch_id, unit_status) VALUES (12, 'SN-DOLO-G-0001', 7, 'FLAGGED')
SELECT * FROM dual;

-- SHIPMENT (shipment 9 is still in transit: receive_date stays NULL)
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (1, 1, 3, TIMESTAMP '2026-01-15 08:00:00', TIMESTAMP '2026-01-16 14:00:00', 'TN-01-AB-1234', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (2, 3, 5, TIMESTAMP '2026-01-20 09:30:00', TIMESTAMP '2026-01-21 11:00:00', 'TN-38-CD-5678', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (3, 1, 4, TIMESTAMP '2026-02-20 07:00:00', TIMESTAMP '2026-02-22 12:00:00', 'TN-01-EF-9012', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (4, 4, 6, TIMESTAMP '2026-02-25 10:00:00', TIMESTAMP '2026-02-26 15:30:00', 'KA-05-GH-3456', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (5, 2, 3, TIMESTAMP '2026-03-05 06:00:00', TIMESTAMP '2026-03-06 10:00:00', 'MH-12-IJ-7890', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (6, 3, 7, TIMESTAMP '2026-03-10 08:00:00', TIMESTAMP '2026-03-11 11:00:00', 'TN-38-KL-2345', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (7, 1, 5, TIMESTAMP '2026-04-25 09:00:00', TIMESTAMP '2026-04-26 12:00:00', 'TN-01-MN-6789', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
VALUES (8, 2, 10, TIMESTAMP '2026-05-10 05:30:00', TIMESTAMP '2026-05-12 10:00:00', 'MH-12-OP-0123', 'DELIVERED');
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date, vehicle_no)
VALUES (9, 3, 5, TIMESTAMP '2026-10-17 09:00:00', 'TN-38-QR-4567');

-- CUSTODY_TRANSFER: hash-linked chains (genesis hash = 64 zeros)
-- Batch 1: manufacturer -> distributor -> pharmacy
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 1, 1, 1, 1, 6000, g.h, RAWTOHEX(STANDARD_HASH('1|1|1|6000|' || g.h, 'SHA256'))
FROM  (SELECT RPAD('0', 64, '0') AS h FROM dual) g;
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 2, 1, 2, 2, 2000, c.current_hash, RAWTOHEX(STANDARD_HASH('1|2|2|2000|' || c.current_hash, 'SHA256'))
FROM   custody_transfer c WHERE c.batch_id = 1 AND c.seq_no = 1;

-- Batch 2: manufacturer -> wholesaler -> pharmacy
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 3, 2, 3, 1, 3000, g.h, RAWTOHEX(STANDARD_HASH('2|3|1|3000|' || g.h, 'SHA256'))
FROM  (SELECT RPAD('0', 64, '0') AS h FROM dual) g;
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 4, 2, 4, 2, 1000, c.current_hash, RAWTOHEX(STANDARD_HASH('2|4|2|1000|' || c.current_hash, 'SHA256'))
FROM   custody_transfer c WHERE c.batch_id = 2 AND c.seq_no = 1;

-- Batch 3 (insulin): manufacturer -> distributor -> hospital
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 5, 3, 5, 1, 1500, g.h, RAWTOHEX(STANDARD_HASH('3|5|1|1500|' || g.h, 'SHA256'))
FROM  (SELECT RPAD('0', 64, '0') AS h FROM dual) g;
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 6, 3, 6, 2, 500, c.current_hash, RAWTOHEX(STANDARD_HASH('3|6|2|500|' || c.current_hash, 'SHA256'))
FROM   custody_transfer c WHERE c.batch_id = 3 AND c.seq_no = 1;

-- Batch 5: manufacturer -> pharmacy (direct)
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 7, 5, 7, 1, 2000, g.h, RAWTOHEX(STANDARD_HASH('5|7|1|2000|' || g.h, 'SHA256'))
FROM  (SELECT RPAD('0', 64, '0') AS h FROM dual) g;

-- Batch 6 (vaccine): manufacturer -> pharmacy
INSERT INTO custody_transfer (transfer_id, batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
SELECT 8, 6, 8, 1, 800, g.h, RAWTOHEX(STANDARD_HASH('6|8|1|800|' || g.h, 'SHA256'))
FROM  (SELECT RPAD('0', 64, '0') AS h FROM dual) g;

-- STORAGE_LOG (log 6 breaks the 2 to 8 degree range of insulin: a cold-chain violation)
INSERT ALL
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (1,  1, 1,  NULL, TIMESTAMP '2026-01-12 10:00:00', 24.5, 50)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (2,  1, 3,  1,    TIMESTAMP '2026-01-16 13:00:00', 26.0, 55)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (3,  2, 4,  3,    TIMESTAMP '2026-02-22 12:00:00', 22.0, 60)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (4,  3, 2,  NULL, TIMESTAMP '2026-03-02 09:00:00',  5.5, 45)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (5,  3, 3,  5,    TIMESTAMP '2026-03-06 10:00:00',  6.8, 48)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (6,  3, 3,  5,    TIMESTAMP '2026-03-06 16:00:00', 12.5, 50)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (7,  3, 7,  6,    TIMESTAMP '2026-03-11 11:00:00',  7.2, 47)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (8,  6, 2,  NULL, TIMESTAMP '2026-05-06 09:00:00',  4.0, 40)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (9,  6, 10, 8,    TIMESTAMP '2026-05-12 10:00:00',  5.1, 42)
  INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
       VALUES (10, 5, 5,  7,    TIMESTAMP '2026-04-26 12:00:00', 28.0, 70)
SELECT * FROM dual;

-- DISPENSING_RECORD (dispense_date uses its DEFAULT only when omitted; dates given here)
INSERT INTO dispensing_record (dispense_id, unit_id, pharmacy_id, patient_id, dispense_date, prescription_ref)
VALUES (1, 1, 5, 1, DATE '2026-02-10', NULL);
INSERT INTO dispensing_record (dispense_id, unit_id, pharmacy_id, patient_id, dispense_date, prescription_ref)
VALUES (2, 4, 6, 2, DATE '2026-03-05', 'RX-2026-0042');
INSERT INTO dispensing_record (dispense_id, unit_id, pharmacy_id, patient_id, dispense_date, prescription_ref)
VALUES (3, 6, 7, 3, DATE '2026-03-20', 'RX-2026-0101');
INSERT INTO dispensing_record (dispense_id, unit_id, pharmacy_id, patient_id, dispense_date, prescription_ref)
VALUES (4, 8, 5, 4, DATE '2026-05-02', 'RX-2026-0177');
INSERT INTO dispensing_record (dispense_id, unit_id, pharmacy_id, patient_id, dispense_date, prescription_ref)
VALUES (5, 10, 10, 5, DATE '2026-06-01', 'RX-2026-0230');

-- ALERT (raised_at and alert_status use their DEFAULTs)
INSERT INTO alert (alert_id, alert_type, batch_id, unit_id, description)
VALUES (1, 'COLD_CHAIN', 3, NULL, 'Temperature 12.5 C exceeded the 8 C limit during shipment 5');
INSERT INTO alert (alert_id, alert_type, batch_id, unit_id, description)
VALUES (2, 'EXPIRED', 4, NULL, 'Batch CET-2025-D passed its expiry date');
INSERT INTO alert (alert_id, alert_type, batch_id, unit_id, description)
VALUES (3, 'RECALLED', 7, NULL, 'Regulator recall of batch DOLO-2026-G');
INSERT INTO alert (alert_id, alert_type, batch_id, unit_id, description)
VALUES (4, 'DUPLICATE_SERIAL', NULL, 12, 'Serial SN-DOLO-G-0001 scanned at two locations');

-- USER_ACCOUNT (is_active uses its DEFAULT)
INSERT ALL
  INTO user_account (user_id, username, role_name, party_id) VALUES (1, 'admin',          'ADMIN',        NULL)
  INTO user_account (user_id, username, role_name, party_id) VALUES (2, 'regulator_cdsco', 'REGULATOR',    NULL)
  INTO user_account (user_id, username, role_name, party_id) VALUES (3, 'auditor_01',     'AUDITOR',      NULL)
  INTO user_account (user_id, username, role_name, party_id) VALUES (4, 'mfr_sunpharma',  'MANUFACTURER', 1)
  INTO user_account (user_id, username, role_name, party_id) VALUES (5, 'dist_apex',      'DISTRIBUTOR',  3)
  INTO user_account (user_id, username, role_name, party_id) VALUES (6, 'pharm_vellore',  'PHARMACY',     5)
SELECT * FROM dual;

COMMIT;

-- ------------------------------ PART B: UPDATE -----------------------

-- 1. Single row
UPDATE party SET phone = '+919443000099' WHERE party_id = 5;

-- 2. Several rows at once: mark every active batch past its expiry date as EXPIRED
UPDATE batch
SET    batch_status = 'EXPIRED'
WHERE  expiry_date < SYSDATE AND batch_status = 'ACTIVE';

-- 3. Several columns: the in-transit shipment is delivered
UPDATE shipment
SET    shipment_status = 'DELIVERED',
       receive_date    = TIMESTAMP '2026-10-18 11:30:00'
WHERE  shipment_id = 9;

-- 4. Deactivate a user account
UPDATE user_account SET is_active = 'N' WHERE username = 'pharm_vellore';

-- 5. Planned failure: breaks ck_batch_dates (ORA-02290)
UPDATE batch SET expiry_date = DATE '2020-01-01' WHERE batch_id = 1;

COMMIT;

-- ------------------------------ PART C: DELETE -----------------------

-- 1. Delete rows we just created
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry)
VALUES (11, 'Temp Trader A', 'WHOLESALER', 'WHL-TMP-0001', DATE '2027-12-31');
INSERT INTO party (party_id, party_name, party_type, license_no, license_expiry)
VALUES (12, 'Temp Trader B', 'WHOLESALER', 'WHL-TMP-0002', DATE '2027-12-31');
DELETE FROM party WHERE party_id IN (11, 12);

-- 2. ON DELETE SET NULL in action (fk_log_shipment)
INSERT INTO shipment (shipment_id, from_party_id, to_party_id, dispatch_date)
VALUES (10, 3, 6, TIMESTAMP '2026-10-18 09:00:00');
INSERT INTO storage_log (log_id, batch_id, party_id, shipment_id, recorded_at, temperature_c, humidity_pct)
VALUES (11, 1, 3, 10, TIMESTAMP '2026-10-18 10:00:00', 25.0, 52);
DELETE FROM shipment WHERE shipment_id = 10;
SELECT log_id, shipment_id FROM storage_log WHERE log_id = 11;   -- shipment_id is now NULL
DELETE FROM storage_log WHERE log_id = 11;

-- 3. Planned failure: party 1 still has batches (ORA-02292 child record found)
DELETE FROM party WHERE party_id = 1;

COMMIT;

-- Note: today custody_transfer and audit_log rows can still be updated or deleted.
-- The immutability triggers in Review 2 will block that.

-- ------------------------------ PART D: VERIFY -----------------------

SELECT 'PARTY' AS table_name, COUNT(*) AS total_rows FROM party
UNION ALL SELECT 'DRUG',              COUNT(*) FROM drug
UNION ALL SELECT 'PATIENT',           COUNT(*) FROM patient
UNION ALL SELECT 'BATCH',             COUNT(*) FROM batch
UNION ALL SELECT 'DRUG_UNIT',         COUNT(*) FROM drug_unit
UNION ALL SELECT 'SHIPMENT',          COUNT(*) FROM shipment
UNION ALL SELECT 'CUSTODY_TRANSFER',  COUNT(*) FROM custody_transfer
UNION ALL SELECT 'STORAGE_LOG',       COUNT(*) FROM storage_log
UNION ALL SELECT 'DISPENSING_RECORD', COUNT(*) FROM dispensing_record
UNION ALL SELECT 'ALERT',             COUNT(*) FROM alert
UNION ALL SELECT 'USER_ACCOUNT',      COUNT(*) FROM user_account;

SELECT batch_id, batch_no, batch_status FROM batch ORDER BY batch_id;

SELECT transfer_id, batch_id, seq_no, SUBSTR(previous_hash, 1, 10) AS prev_hash_start,
       SUBSTR(current_hash, 1, 10) AS curr_hash_start
FROM   custody_transfer ORDER BY batch_id, seq_no;

-- Re-sync identity counters so later INSERTs without an ID do not collide
-- with the explicit IDs used above (needs Oracle 12.2 or later).
ALTER TABLE party             MODIFY (party_id    GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE drug              MODIFY (drug_id     GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE patient           MODIFY (patient_id  GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE batch             MODIFY (batch_id    GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE drug_unit         MODIFY (unit_id     GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE shipment          MODIFY (shipment_id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE custody_transfer  MODIFY (transfer_id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE storage_log       MODIFY (log_id      GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE dispensing_record MODIFY (dispense_id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE alert             MODIFY (alert_id    GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE user_account      MODIFY (user_id     GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE));