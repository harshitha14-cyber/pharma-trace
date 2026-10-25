-- =====================================================================
-- Pharma-Trace | Review 2 | 06_subqueries_joins.sql   (Oracle 12c or later)
-- Run AFTER 03_dml_insert.sql. Read-only except one rolled-back UPDATE.
-- =====================================================================

-- ============================ A. SUBQUERIES ==========================

-- 1. Single-row subquery: batches bigger than the average batch
SELECT batch_no, quantity_produced FROM batch
WHERE  quantity_produced > (SELECT AVG(quantity_produced) FROM batch);

-- 2. Multi-row subquery with IN: drugs that have a recalled batch
SELECT drug_name FROM drug
WHERE  drug_id IN (SELECT drug_id FROM batch WHERE batch_status = 'RECALLED');

-- 3. NOT EXISTS: parties that never sent or received a shipment
SELECT p.party_name, p.license_status FROM party p
WHERE  NOT EXISTS (SELECT 1 FROM shipment s
                   WHERE s.from_party_id = p.party_id OR s.to_party_id = p.party_id);

-- 4. ANY and ALL
SELECT batch_no, quantity_produced FROM batch
WHERE  quantity_produced > ALL (SELECT quantity_produced FROM batch
                                WHERE batch_status IN ('RECALLED', 'QUARANTINED'));
SELECT batch_no, quantity_produced FROM batch
WHERE  quantity_produced > ANY (SELECT quantity_produced FROM batch WHERE drug_id = 2);

-- 5. Correlated subquery in SELECT: hops per batch (0 for batches never moved)
SELECT b.batch_no,
       (SELECT COUNT(*) FROM custody_transfer ct WHERE ct.batch_id = b.batch_id) AS hops
FROM   batch b ORDER BY b.batch_id;

-- 6. Correlated subquery in WHERE: parties that sent more than one shipment
SELECT p.party_name FROM party p
WHERE  (SELECT COUNT(*) FROM shipment s WHERE s.from_party_id = p.party_id) > 1;

-- 7. Inline view: manufacturer with the highest total production
SELECT * FROM (SELECT manufacturer_id, SUM(quantity_produced) AS total
               FROM batch GROUP BY manufacturer_id ORDER BY total DESC)
WHERE  ROWNUM = 1;

-- 8. Subquery in HAVING: manufacturers above the average manufacturer total
SELECT manufacturer_id, SUM(quantity_produced) AS total FROM batch
GROUP  BY manufacturer_id
HAVING SUM(quantity_produced) > (SELECT AVG(t) FROM (SELECT SUM(quantity_produced) AS t
                                                     FROM batch GROUP BY manufacturer_id));

-- 9. WITH clause (subquery factoring)
WITH moved AS (SELECT batch_id, SUM(quantity) AS qty_moved FROM custody_transfer GROUP BY batch_id)
SELECT b.batch_no, b.quantity_produced, NVL(m.qty_moved, 0) AS qty_moved,
       b.quantity_produced - NVL(m.qty_moved, 0) AS still_at_maker
FROM   batch b LEFT JOIN moved m ON m.batch_id = b.batch_id ORDER BY b.batch_id;

-- 10. Subquery inside UPDATE (rolled back)
UPDATE drug_unit SET unit_status = 'FLAGGED'
WHERE  batch_id IN (SELECT batch_id FROM batch WHERE batch_status = 'QUARANTINED');
ROLLBACK;

-- ============================== B. JOINS =============================

-- 1. INNER JOIN across three tables
SELECT b.batch_no, d.drug_name, p.party_name AS manufacturer, b.batch_status
FROM   batch b JOIN drug d  ON d.drug_id  = b.drug_id
               JOIN party p ON p.party_id = b.manufacturer_id
ORDER  BY b.batch_id;

-- 2. Two joins to the same table (sender and receiver)
SELECT s.shipment_id, pf.party_name AS sender, pt.party_name AS receiver, s.shipment_status
FROM   shipment s JOIN party pf ON pf.party_id = s.from_party_id
                  JOIN party pt ON pt.party_id = s.to_party_id
ORDER  BY s.shipment_id;

-- 3. LEFT JOIN: every batch, even those never moved
SELECT b.batch_no, b.batch_status, COUNT(ct.transfer_id) AS hops
FROM   batch b LEFT JOIN custody_transfer ct ON ct.batch_id = b.batch_id
GROUP  BY b.batch_no, b.batch_status, b.batch_id ORDER BY b.batch_id;

-- 4. RIGHT JOIN: every pharmacy or hospital, with its dispensing count
SELECT p.party_name, COUNT(dr.dispense_id) AS dispensed
FROM   dispensing_record dr RIGHT JOIN party p ON p.party_id = dr.pharmacy_id
WHERE  p.party_type IN ('PHARMACY', 'HOSPITAL')
GROUP  BY p.party_name ORDER BY dispensed DESC;

-- 5. FULL OUTER JOIN: parties against the shipments they sent
SELECT p.party_name, s.shipment_id
FROM   party p FULL OUTER JOIN shipment s ON s.from_party_id = p.party_id
ORDER  BY p.party_name, s.shipment_id;

-- 6. SELF JOIN: consecutive hand-overs whose hashes link up
SELECT a.batch_id, a.seq_no AS from_seq, b.seq_no AS to_seq,
       CASE WHEN b.previous_hash = a.current_hash THEN 'LINKED' ELSE 'BROKEN' END AS link
FROM   custody_transfer a JOIN custody_transfer b
       ON b.batch_id = a.batch_id AND b.seq_no = a.seq_no + 1;

-- 7. CROSS JOIN: every pharmacy against every prescription drug
SELECT p.party_name, d.drug_name
FROM   party p CROSS JOIN drug d
WHERE  p.party_type = 'PHARMACY' AND d.requires_prescription = 'Y';

-- 8. JOIN ... USING
SELECT batch_no, drug_name FROM batch JOIN drug USING (drug_id);

-- 9. Non-equi join: readings outside the drug's allowed temperature range
SELECT sl.log_id, b.batch_no, d.drug_name, sl.temperature_c, d.min_storage_temp, d.max_storage_temp
FROM   storage_log sl JOIN batch b ON b.batch_id = sl.batch_id
                      JOIN drug d  ON d.drug_id  = b.drug_id
                       AND sl.temperature_c NOT BETWEEN d.min_storage_temp AND d.max_storage_temp;

-- ===================== C. PROJECT QUESTIONS ==========================

-- P1. Full journey of batch 1 in order
SELECT ct.seq_no, pf.party_name AS from_party, pt.party_name AS to_party, ct.quantity, s.dispatch_date
FROM   custody_transfer ct JOIN shipment s ON s.shipment_id = ct.shipment_id
                           JOIN party pf   ON pf.party_id = s.from_party_id
                           JOIN party pt   ON pt.party_id = s.to_party_id
WHERE  ct.batch_id = 1 ORDER BY ct.seq_no;

-- P2. Shipments involving a party whose license was not valid at dispatch (rule 3)
SELECT s.shipment_id, p.party_name, p.license_status, p.license_expiry, s.dispatch_date
FROM   shipment s JOIN party p ON p.party_id IN (s.from_party_id, s.to_party_id)
WHERE  p.license_status <> 'ACTIVE' OR p.license_expiry < TRUNC(s.dispatch_date);

-- P3. Who dispensed what to whom
SELECT dr.dispense_date, d.drug_name, du.serial_no, ph.party_name AS pharmacy, pa.patient_name
FROM   dispensing_record dr JOIN drug_unit du ON du.unit_id = dr.unit_id
                            JOIN batch b      ON b.batch_id = du.batch_id
                            JOIN drug d       ON d.drug_id = b.drug_id
                            JOIN party ph     ON ph.party_id = dr.pharmacy_id
                            JOIN patient pa   ON pa.patient_id = dr.patient_id
ORDER  BY dr.dispense_date;

-- P4. Packs dispensed by a pharmacy that never received that batch (possible fake insertion)
SELECT dr.dispense_id, du.serial_no, dr.pharmacy_id
FROM   dispensing_record dr JOIN drug_unit du ON du.unit_id = dr.unit_id
WHERE  NOT EXISTS (SELECT 1 FROM custody_transfer ct JOIN shipment s ON s.shipment_id = ct.shipment_id
                   WHERE  ct.batch_id = du.batch_id AND s.to_party_id = dr.pharmacy_id);