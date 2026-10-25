-- =====================================================================
-- Pharma-Trace | Review 2 | 08_functions_procedures.sql   (Oracle PL/SQL)
-- Run AFTER 07_views.sql. In SQL Developer use "Run Script" (F5).
-- Needs CREATE PROCEDURE (granted in 00_create_user.sql).
-- =====================================================================

-- ------------------------------ FUNCTIONS ----------------------------

-- SHA-256 fingerprint of one hand-over (same formula as the data script)
CREATE OR REPLACE FUNCTION fn_calc_hash(p_batch NUMBER, p_ship NUMBER, p_seq NUMBER,
                                        p_qty NUMBER, p_prev VARCHAR2)
RETURN VARCHAR2 DETERMINISTIC IS
BEGIN
  RETURN RAWTOHEX(STANDARD_HASH(p_batch || '|' || p_ship || '|' || p_seq || '|' || p_qty || '|' || p_prev, 'SHA256'));
END fn_calc_hash;
/

-- 1 if the party has an active, unexpired license, otherwise 0
CREATE OR REPLACE FUNCTION fn_is_authorized(p_party NUMBER) RETURN NUMBER IS
  v_ok NUMBER;
BEGIN
  SELECT CASE WHEN license_status = 'ACTIVE' AND license_expiry >= TRUNC(SYSDATE) THEN 1 ELSE 0 END
  INTO   v_ok FROM party WHERE party_id = p_party;
  RETURN v_ok;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN 0;
END fn_is_authorized;
/

-- How many units of a batch a party holds: produced + received - sent
CREATE OR REPLACE FUNCTION fn_qty_held(p_batch NUMBER, p_party NUMBER) RETURN NUMBER IS
  v_prod NUMBER; v_in NUMBER; v_out NUMBER;
BEGIN
  SELECT NVL(SUM(quantity_produced), 0) INTO v_prod FROM batch
  WHERE  batch_id = p_batch AND manufacturer_id = p_party;
  SELECT NVL(SUM(ct.quantity), 0) INTO v_in FROM custody_transfer ct
         JOIN shipment s ON s.shipment_id = ct.shipment_id
  WHERE  ct.batch_id = p_batch AND s.to_party_id = p_party;
  SELECT NVL(SUM(ct.quantity), 0) INTO v_out FROM custody_transfer ct
         JOIN shipment s ON s.shipment_id = ct.shipment_id
  WHERE  ct.batch_id = p_batch AND s.from_party_id = p_party;
  RETURN v_prod + v_in - v_out;
END fn_qty_held;
/

-- VALID, NO TRANSFERS, or TAMPERED at seq N
CREATE OR REPLACE FUNCTION fn_verify_chain(p_batch NUMBER) RETURN VARCHAR2 IS
  v_bad NUMBER; v_rows NUMBER;
BEGIN
  SELECT COUNT(*), MIN(CASE WHEN hash_status = 'BAD' OR link_status = 'BROKEN' THEN seq_no END)
  INTO   v_rows, v_bad FROM v_chain_verification WHERE batch_id = p_batch;
  IF v_rows = 0 THEN RETURN 'NO TRANSFERS'; END IF;
  IF v_bad IS NULL THEN RETURN 'VALID'; END IF;
  RETURN 'TAMPERED at seq ' || v_bad;
END fn_verify_chain;
/

-- ----------------------------- PROCEDURES ----------------------------

-- Record a hand-over: validates the business rules, then writes shipment + hash-linked transfer
CREATE OR REPLACE PROCEDURE sp_record_transfer(p_batch IN NUMBER, p_from IN NUMBER, p_to IN NUMBER,
                                               p_qty IN NUMBER, p_vehicle IN VARCHAR2 DEFAULT NULL) IS
  v_status batch.batch_status%TYPE;
  v_expiry batch.expiry_date%TYPE;
  v_seq    NUMBER;
  v_prev   VARCHAR2(64);
  v_ship   NUMBER;
  v_now    TIMESTAMP := SYSTIMESTAMP;
BEGIN
  -- lock the batch row so two people cannot extend the same chain at once
  SELECT batch_status, expiry_date INTO v_status, v_expiry FROM batch WHERE batch_id = p_batch FOR UPDATE;

  IF p_from = p_to THEN RAISE_APPLICATION_ERROR(-20010, 'Sender and receiver must differ'); END IF;
  IF fn_is_authorized(p_from) = 0 OR fn_is_authorized(p_to) = 0 THEN
    RAISE_APPLICATION_ERROR(-20011, 'A party has no valid license (unauthorized seller)');
  END IF;
  IF v_status <> 'ACTIVE' OR v_expiry < SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20012, 'Batch is ' || v_status || ' or expired and cannot be moved');
  END IF;
  IF p_qty <= 0 OR fn_qty_held(p_batch, p_from) < p_qty THEN
    RAISE_APPLICATION_ERROR(-20013, 'Sender does not hold that quantity (broken chain)');
  END IF;

  SELECT NVL(MAX(seq_no), 0) + 1 INTO v_seq FROM custody_transfer WHERE batch_id = p_batch;
  IF v_seq = 1 THEN
    v_prev := RPAD('0', 64, '0');
  ELSE
    SELECT current_hash INTO v_prev FROM custody_transfer WHERE batch_id = p_batch AND seq_no = v_seq - 1;
  END IF;

  INSERT INTO shipment (from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
  VALUES (p_from, p_to, v_now, v_now, p_vehicle, 'DELIVERED') RETURNING shipment_id INTO v_ship;

  INSERT INTO custody_transfer (batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
  VALUES (p_batch, v_ship, v_seq, p_qty, v_prev, fn_calc_hash(p_batch, v_ship, v_seq, p_qty, v_prev));

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Transfer recorded: batch ' || p_batch || ', seq ' || v_seq);
EXCEPTION
  WHEN NO_DATA_FOUND THEN ROLLBACK; RAISE_APPLICATION_ERROR(-20014, 'Batch not found');
  WHEN OTHERS THEN ROLLBACK; RAISE;
END sp_record_transfer;
/

-- Dispense one pack (by serial number) to a patient
CREATE OR REPLACE PROCEDURE sp_dispense_unit(p_serial IN VARCHAR2, p_pharmacy IN NUMBER,
                                             p_patient IN NUMBER, p_rx IN VARCHAR2 DEFAULT NULL) IS
  v_unit   drug_unit.unit_id%TYPE;
  v_batch  drug_unit.batch_id%TYPE;
  v_ustat  drug_unit.unit_status%TYPE;
  v_type   party.party_type%TYPE;
BEGIN
  SELECT unit_id, batch_id, unit_status INTO v_unit, v_batch, v_ustat
  FROM   drug_unit WHERE serial_no = p_serial FOR UPDATE;
  SELECT party_type INTO v_type FROM party WHERE party_id = p_pharmacy;

  IF v_type NOT IN ('PHARMACY', 'HOSPITAL') THEN RAISE_APPLICATION_ERROR(-20020, 'Only a pharmacy or hospital may dispense'); END IF;
  IF fn_is_authorized(p_pharmacy) = 0 THEN RAISE_APPLICATION_ERROR(-20021, 'Pharmacy license is not valid'); END IF;
  IF v_ustat <> 'IN_STOCK' THEN RAISE_APPLICATION_ERROR(-20022, 'Pack is ' || v_ustat || ', cannot dispense'); END IF;
  IF fn_qty_held(v_batch, p_pharmacy) <= 0 THEN RAISE_APPLICATION_ERROR(-20023, 'Pharmacy never received this batch'); END IF;

  INSERT INTO dispensing_record (unit_id, pharmacy_id, patient_id, prescription_ref)
  VALUES (v_unit, p_pharmacy, p_patient, p_rx);   -- triggers check rules and mark the pack DISPENSED
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Dispensed ' || p_serial);
EXCEPTION
  WHEN NO_DATA_FOUND THEN ROLLBACK; RAISE_APPLICATION_ERROR(-20024, 'Serial number or pharmacy not found');
  WHEN OTHERS THEN ROLLBACK; RAISE;
END sp_dispense_unit;
/

-- Regulator recall: mark the batch and raise an alert
CREATE OR REPLACE PROCEDURE sp_recall_batch(p_batch IN NUMBER, p_reason IN VARCHAR2) IS
BEGIN
  UPDATE batch SET batch_status = 'RECALLED' WHERE batch_id = p_batch;
  IF SQL%ROWCOUNT = 0 THEN RAISE_APPLICATION_ERROR(-20030, 'Batch not found'); END IF;
  INSERT INTO alert (alert_type, batch_id, description) VALUES ('RECALLED', p_batch, p_reason);
  COMMIT;
END sp_recall_batch;
/

-- ------------------------------ try them -----------------------------
SET SERVEROUTPUT ON
SELECT fn_is_authorized(1) AS maker_ok, fn_is_authorized(8) AS expired_ok FROM dual;
SELECT fn_qty_held(1, 1) AS at_maker, fn_qty_held(1, 3) AS at_distributor, fn_qty_held(1, 5) AS at_pharmacy FROM dual;
SELECT batch_id, fn_verify_chain(batch_id) AS chain_status FROM batch ORDER BY batch_id;