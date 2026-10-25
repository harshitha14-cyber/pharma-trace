-- =====================================================================
-- Pharma-Trace | Review 2 | 07_views.sql   (Oracle 12c or later)
-- Run AFTER 03_dml_insert.sql. Needs CREATE VIEW (granted in 00_create_user.sql).
-- =====================================================================

-- Batch overview: drug, maker, status, days left, pack counts
CREATE OR REPLACE VIEW v_batch_overview AS
SELECT b.batch_id, b.batch_no, d.drug_name, p.party_name AS manufacturer, b.batch_status,
       b.expiry_date, TRUNC(b.expiry_date - SYSDATE) AS days_to_expiry,
       (SELECT COUNT(*) FROM drug_unit u WHERE u.batch_id = b.batch_id) AS packs,
       (SELECT COUNT(*) FROM drug_unit u WHERE u.batch_id = b.batch_id AND u.unit_status = 'DISPENSED') AS dispensed
FROM   batch b JOIN drug d ON d.drug_id = b.drug_id JOIN party p ON p.party_id = b.manufacturer_id;

-- Readable custody journey
CREATE OR REPLACE VIEW v_batch_journey AS
SELECT ct.batch_id, b.batch_no, ct.seq_no, pf.party_name AS from_party, pt.party_name AS to_party,
       ct.quantity, s.dispatch_date, SUBSTR(ct.previous_hash, 1, 8) AS prev_hash, SUBSTR(ct.current_hash, 1, 8) AS hash
FROM   custody_transfer ct JOIN batch b    ON b.batch_id = ct.batch_id
                           JOIN shipment s ON s.shipment_id = ct.shipment_id
                           JOIN party pf   ON pf.party_id = s.from_party_id
                           JOIN party pt   ON pt.party_id = s.to_party_id;

-- Hash chain verification: recompute each hash and check the link to the previous row
CREATE OR REPLACE VIEW v_chain_verification AS
SELECT ct.transfer_id, ct.batch_id, ct.seq_no,
       CASE WHEN ct.current_hash = RAWTOHEX(STANDARD_HASH(
                 ct.batch_id || '|' || ct.shipment_id || '|' || ct.seq_no || '|' || ct.quantity || '|' || ct.previous_hash,
                 'SHA256')) THEN 'OK' ELSE 'BAD' END AS hash_status,
       CASE WHEN ct.previous_hash = NVL(LAG(ct.current_hash) OVER (PARTITION BY ct.batch_id ORDER BY ct.seq_no),
                                        RPAD('0', 64, '0')) THEN 'OK' ELSE 'BROKEN' END AS link_status
FROM   custody_transfer ct;

-- Cold-chain breaches
CREATE OR REPLACE VIEW v_cold_chain_breaches AS
SELECT sl.log_id, b.batch_no, d.drug_name, sl.recorded_at, sl.temperature_c,
       d.min_storage_temp, d.max_storage_temp
FROM   storage_log sl JOIN batch b ON b.batch_id = sl.batch_id JOIN drug d ON d.drug_id = b.drug_id
WHERE  sl.temperature_c < d.min_storage_temp OR sl.temperature_c > d.max_storage_temp;

-- Batches expired or expiring within six months
CREATE OR REPLACE VIEW v_expiring_batches AS
SELECT batch_id, batch_no, batch_status, expiry_date, TRUNC(expiry_date - SYSDATE) AS days_left,
       CASE WHEN expiry_date < SYSDATE THEN 'EXPIRED' ELSE 'EXPIRING SOON' END AS flag
FROM   batch WHERE expiry_date < ADD_MONTHS(SYSDATE, 6);

-- Which parties may trade today
CREATE OR REPLACE VIEW v_party_authorization AS
SELECT party_id, party_name, party_type, license_status, license_expiry,
       CASE WHEN license_status = 'ACTIVE' AND license_expiry >= TRUNC(SYSDATE)
            THEN 'AUTHORIZED' ELSE 'NOT AUTHORIZED' END AS trading_status
FROM   party;

-- Open alerts, newest first
CREATE OR REPLACE VIEW v_open_alerts AS
SELECT alert_id, alert_type, batch_id, unit_id, description, raised_at
FROM   alert WHERE alert_status = 'OPEN';

-- Updatable view with a safety check: only ACTIVE batches can be inserted or changed through it
CREATE OR REPLACE VIEW v_active_batches AS
SELECT batch_id, batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced, batch_status
FROM   batch WHERE batch_status = 'ACTIVE' WITH CHECK OPTION;

-- Read-only view for pharmacies (no patient personal details)
CREATE OR REPLACE VIEW v_pharmacy_dispensing AS
SELECT dr.dispense_id, dr.pharmacy_id, du.serial_no, dr.dispense_date, dr.prescription_ref
FROM   dispensing_record dr JOIN drug_unit du ON du.unit_id = dr.unit_id
WITH READ ONLY;

-- ---------------------------- try them -------------------------------
SELECT * FROM v_batch_overview ORDER BY batch_id;
SELECT * FROM v_batch_journey WHERE batch_id = 1 ORDER BY seq_no;
SELECT * FROM v_chain_verification ORDER BY batch_id, seq_no;
SELECT * FROM v_cold_chain_breaches;
SELECT * FROM v_expiring_batches ORDER BY expiry_date;
SELECT * FROM v_party_authorization ORDER BY party_id;

-- WITH CHECK OPTION in action (fails with ORA-01402)
UPDATE v_active_batches SET batch_status = 'RECALLED' WHERE batch_id = 1;
ROLLBACK;