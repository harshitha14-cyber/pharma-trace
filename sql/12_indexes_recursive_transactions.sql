-- =====================================================================
-- Pharma-Trace | Extras | 12_indexes_recursive_transactions.sql
-- Run as pharma_trace after 10_triggers.sql.
-- =====================================================================

-- ------------------------------- INDEXES -----------------------------
-- Oracle does not index foreign keys automatically; these speed up joins and lookups.
CREATE INDEX idx_unit_batch      ON drug_unit (batch_id);
CREATE INDEX idx_batch_drug      ON batch (drug_id);
CREATE INDEX idx_batch_mfr       ON batch (manufacturer_id);
CREATE INDEX idx_ship_from       ON shipment (from_party_id);
CREATE INDEX idx_ship_to         ON shipment (to_party_id);
CREATE INDEX idx_ct_shipment     ON custody_transfer (shipment_id);
CREATE INDEX idx_log_batch_time  ON storage_log (batch_id, recorded_at);
CREATE INDEX idx_disp_pharmacy   ON dispensing_record (pharmacy_id);
CREATE INDEX idx_alert_status    ON alert (alert_status, alert_type);
CREATE INDEX idx_unit_serial_ci  ON drug_unit (UPPER(serial_no));   -- function-based: fast case-insensitive scan lookup

EXPLAIN PLAN FOR SELECT * FROM drug_unit WHERE UPPER(serial_no) = 'SN-DOLO-A-0001';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- --------------------- RECURSIVE QUERY (journey) ---------------------
-- Follow the chain from the genesis hash by matching previous_hash to the prior current_hash
WITH chain (batch_id, seq_no, transfer_id, current_hash, shipment_id, lvl) AS (
  SELECT batch_id, seq_no, transfer_id, current_hash, shipment_id, 1
  FROM   custody_transfer
  WHERE  batch_id = 1 AND previous_hash = RPAD('0', 64, '0')
  UNION ALL
  SELECT c.batch_id, c.seq_no, c.transfer_id, c.current_hash, c.shipment_id, p.lvl + 1
  FROM   custody_transfer c JOIN chain p ON c.batch_id = p.batch_id AND c.previous_hash = p.current_hash
)
SELECT ch.lvl AS step, pf.party_name AS from_party, pt.party_name AS to_party
FROM   chain ch JOIN shipment s ON s.shipment_id = ch.shipment_id
                JOIN party pf   ON pf.party_id = s.from_party_id
                JOIN party pt   ON pt.party_id = s.to_party_id
ORDER  BY ch.lvl;

-- ------------------------- TRANSACTIONS (ACID) -----------------------
-- Atomicity: both changes or neither
SAVEPOINT before_change;
UPDATE party SET license_status = 'REVOKED' WHERE party_id = 3;
UPDATE batch SET batch_status = 'QUARANTINED' WHERE batch_id = 2;
ROLLBACK TO before_change;      -- undo both
ROLLBACK;

-- Isolation and locking: run these in TWO SQL Developer sessions (both as pharma_trace)
--   Session A:  SELECT * FROM batch WHERE batch_id = 1 FOR UPDATE;      (do not commit)
--   Session B:  SELECT * FROM batch WHERE batch_id = 1 FOR UPDATE NOWAIT;   -> ORA-00054 resource busy
--   Session B:  EXEC sp_record_transfer(1, 3, 5, 100);                  -> waits until A commits or rolls back
--   Session A:  ROLLBACK;                                               -> B continues