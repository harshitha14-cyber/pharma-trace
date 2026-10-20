-- =====================================================================
-- Pharma-Trace | Review 1 | 05_group_functions_operators.sql   (Oracle 12c or later)
-- Run AFTER 03_dml_insert.sql. Read-only queries.
-- Sections: 1 Operators | 2 Set operators | 3 Group functions |
--           4 GROUP BY and HAVING | 5 Extra grouping features
-- =====================================================================

-- ============================ 1. OPERATORS ===========================

-- Arithmetic: + - * /
SELECT batch_no, quantity_produced,
       ROUND(quantity_produced * 0.02) AS qc_sample_units,
       quantity_produced / 4           AS quarter_lot,
       quantity_produced - 1500        AS after_first_dispatch
FROM   batch ORDER BY batch_id;

-- Precedence: * before +, parentheses first
SELECT 2 + 3 * 4 AS no_parentheses, (2 + 3) * 4 AS with_parentheses FROM dual;

-- Comparison: = <> < > <= >=
SELECT batch_no, quantity_produced FROM batch WHERE quantity_produced >= 5000;
SELECT batch_no, batch_status      FROM batch WHERE batch_status <> 'ACTIVE';
SELECT batch_no, expiry_date       FROM batch WHERE expiry_date > DATE '2027-01-01';

-- Logical: AND, OR, NOT
SELECT batch_no, drug_id, quantity_produced FROM batch
WHERE  batch_status = 'ACTIVE' AND quantity_produced > 3000 AND drug_id IN (1, 2);

SELECT batch_no, batch_status FROM batch
WHERE  batch_status = 'RECALLED' OR batch_status = 'QUARANTINED';

SELECT batch_no, batch_status FROM batch WHERE NOT (batch_status = 'ACTIVE');

-- AND binds tighter than OR: these two queries return different rows
SELECT batch_no, batch_status, quantity_produced FROM batch
WHERE  batch_status = 'RECALLED' OR batch_status = 'QUARANTINED' AND quantity_produced > 9000;

SELECT batch_no, batch_status, quantity_produced FROM batch
WHERE  (batch_status = 'RECALLED' OR batch_status = 'QUARANTINED') AND quantity_produced > 9000;

-- BETWEEN (inclusive)
SELECT batch_no, mfg_date FROM batch WHERE mfg_date BETWEEN DATE '2026-01-01' AND DATE '2026-03-31';
SELECT log_id, humidity_pct FROM storage_log WHERE humidity_pct BETWEEN 40 AND 60;

-- IN and NOT IN
SELECT party_name, party_type FROM party WHERE party_type IN ('PHARMACY', 'HOSPITAL');
SELECT batch_no, batch_status FROM batch WHERE batch_status NOT IN ('ACTIVE', 'EXPIRED');

-- LIKE: % = any characters, _ = exactly one character
SELECT party_name FROM party WHERE party_name LIKE '%Pharma%';
SELECT serial_no  FROM drug_unit WHERE serial_no LIKE 'SN-DOLO-_-0001';
SELECT 'matches' AS escape_demo FROM dual WHERE 'ab_cd' LIKE 'ab\_cd' ESCAPE '\';

-- IS NULL and IS NOT NULL (never use = NULL)
SELECT dispense_id, prescription_ref FROM dispensing_record WHERE prescription_ref IS NULL;
SELECT dispense_id, prescription_ref FROM dispensing_record WHERE prescription_ref IS NOT NULL;
SELECT log_id, batch_id FROM storage_log WHERE shipment_id IS NULL;

-- DISTINCT, ORDER BY, and a top-N query (Oracle 12c FETCH FIRST)
SELECT DISTINCT party_type FROM party ORDER BY party_type;

SELECT batch_no, quantity_produced FROM batch
ORDER  BY quantity_produced DESC
FETCH  FIRST 3 ROWS ONLY;

-- ========================= 2. SET OPERATORS ==========================

-- UNION: every party that took part in any shipment, without duplicates
SELECT from_party_id AS party_id FROM shipment
UNION
SELECT to_party_id FROM shipment;

-- UNION ALL keeps duplicates (compare the row counts)
SELECT from_party_id AS party_id FROM shipment
UNION ALL
SELECT to_party_id FROM shipment;

-- INTERSECT: parties that both send and receive goods (the middlemen)
SELECT from_party_id AS party_id FROM shipment
INTERSECT
SELECT to_party_id FROM shipment;

-- MINUS: parties that never appear in any shipment
-- (these include the expired and the revoked license holders)
SELECT party_id FROM party
MINUS
SELECT from_party_id FROM shipment
MINUS
SELECT to_party_id FROM shipment;

-- ========================= 3. GROUP FUNCTIONS ========================

-- COUNT, SUM, AVG, MIN, MAX, STDDEV over a whole table
SELECT COUNT(*)                          AS total_batches,
       SUM(quantity_produced)            AS total_produced,
       ROUND(AVG(quantity_produced))     AS avg_batch_size,
       MIN(quantity_produced)            AS smallest_batch,
       MAX(quantity_produced)            AS largest_batch,
       ROUND(STDDEV(quantity_produced))  AS std_dev
FROM   batch;

-- COUNT(*) vs COUNT(column) vs COUNT(DISTINCT column): NULLs are skipped by COUNT(column)
SELECT COUNT(*)                     AS all_rows,
       COUNT(prescription_ref)      AS with_prescription,
       COUNT(DISTINCT pharmacy_id)  AS distinct_pharmacies
FROM   dispensing_record;

-- MIN and MAX on dates
SELECT MIN(expiry_date) AS earliest_expiry, MAX(expiry_date) AS latest_expiry,
       MIN(mfg_date)    AS oldest_batch,    MAX(mfg_date)    AS newest_batch
FROM   batch;

-- ========================= 4. GROUP BY AND HAVING ====================

-- Parties by type
SELECT party_type, COUNT(*) AS total_parties
FROM   party GROUP BY party_type ORDER BY total_parties DESC, party_type;

-- Batches by status
SELECT batch_status, COUNT(*) AS total_batches
FROM   batch GROUP BY batch_status ORDER BY batch_status;

-- Units by status
SELECT unit_status, COUNT(*) AS total_units
FROM   drug_unit GROUP BY unit_status ORDER BY unit_status;

-- Total produced per manufacturer; HAVING filters groups after aggregation
SELECT manufacturer_id, COUNT(*) AS batches, SUM(quantity_produced) AS total_produced
FROM   batch
GROUP  BY manufacturer_id
HAVING SUM(quantity_produced) > 10000;

-- WHERE filters rows BEFORE grouping, HAVING filters groups AFTER
SELECT manufacturer_id, COUNT(*) AS healthy_batches, SUM(quantity_produced) AS total_produced
FROM   batch
WHERE  batch_status NOT IN ('RECALLED', 'QUARANTINED', 'EXPIRED')
GROUP  BY manufacturer_id
HAVING COUNT(*) >= 2;

-- Shipments sent per party
SELECT from_party_id, COUNT(*) AS shipments_sent
FROM   shipment GROUP BY from_party_id ORDER BY shipments_sent DESC, from_party_id;

-- Custody chain summary per batch
SELECT batch_id, COUNT(*) AS hops, SUM(quantity) AS qty_moved, MAX(seq_no) AS chain_length
FROM   custody_transfer GROUP BY batch_id ORDER BY batch_id;

-- Temperature statistics per batch
SELECT batch_id, COUNT(*) AS readings, ROUND(AVG(temperature_c), 1) AS avg_temp,
       MIN(temperature_c) AS min_temp, MAX(temperature_c) AS max_temp
FROM   storage_log GROUP BY batch_id ORDER BY batch_id;

-- Cold-chain breach: insulin (batch 3) and vaccine (batch 6) must stay at or below 8 C
SELECT batch_id, MAX(temperature_c) AS highest_reading
FROM   storage_log
WHERE  batch_id IN (3, 6)
GROUP  BY batch_id
HAVING MAX(temperature_c) > 8;

-- Pharmacies that dispensed more than once
SELECT pharmacy_id, COUNT(*) AS dispensed_count
FROM   dispensing_record GROUP BY pharmacy_id HAVING COUNT(*) > 1;

-- Grouping by an expression: dispensing per month
SELECT EXTRACT(MONTH FROM dispense_date) AS month_no, COUNT(*) AS dispensed
FROM   dispensing_record
GROUP  BY EXTRACT(MONTH FROM dispense_date)
ORDER  BY month_no;

-- Grouping by two columns
SELECT alert_type, alert_status, COUNT(*) AS total_alerts
FROM   alert GROUP BY alert_type, alert_status ORDER BY alert_type;

-- Counterfeit rule 1 preview: duplicate serial numbers.
-- Returns no rows because uq_unit_serial blocks duplicates; Review 2 checks scans across locations.
SELECT serial_no, COUNT(*) AS occurrences
FROM   drug_unit GROUP BY serial_no HAVING COUNT(*) > 1;

-- ====================== 5. EXTRA GROUPING FEATURES ===================

-- LISTAGG: the shipment path of every batch, in custody order
SELECT batch_id,
       LISTAGG(shipment_id, ' > ') WITHIN GROUP (ORDER BY seq_no) AS shipment_path
FROM   custody_transfer GROUP BY batch_id ORDER BY batch_id;

-- ROLLUP: subtotals and a grand total (NULL in a column marks a subtotal row)
SELECT party_type, license_status, COUNT(*) AS total_parties
FROM   party
GROUP  BY ROLLUP (party_type, license_status)
ORDER  BY party_type, license_status;