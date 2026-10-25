-- =====================================================================
-- Pharma-Trace | Review 2 | 09_cursors.sql   (Oracle PL/SQL)
-- Run AFTER 08_functions_procedures.sql. Use "Run Script" (F5).
-- =====================================================================
SET SERVEROUTPUT ON

-- 1. Implicit cursor: SQL%ROWCOUNT after a DML statement (rolled back)
BEGIN
  UPDATE batch SET batch_status = 'QUARANTINED' WHERE batch_status = 'ACTIVE' AND quantity_produced > 9000;
  DBMS_OUTPUT.PUT_LINE('Rows changed: ' || SQL%ROWCOUNT);
  ROLLBACK;
END;
/

-- 2. Explicit cursor: list batches that are expired or expiring soon
DECLARE
  CURSOR c_exp IS SELECT batch_no, expiry_date FROM batch WHERE expiry_date < ADD_MONTHS(SYSDATE, 6) ORDER BY expiry_date;
  v_no batch.batch_no%TYPE; v_dt batch.expiry_date%TYPE;
BEGIN
  OPEN c_exp;
  LOOP
    FETCH c_exp INTO v_no, v_dt;
    EXIT WHEN c_exp%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(v_no || ' expires ' || TO_CHAR(v_dt, 'DD-Mon-YYYY'));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Total: ' || c_exp%ROWCOUNT);
  CLOSE c_exp;
END;
/

-- 3. Parameterized cursor with a cursor FOR loop: the journey of one batch
DECLARE
  CURSOR c_trip(p_batch NUMBER) IS
    SELECT ct.seq_no, pf.party_name AS f, pt.party_name AS t, ct.quantity
    FROM custody_transfer ct JOIN shipment s ON s.shipment_id = ct.shipment_id
         JOIN party pf ON pf.party_id = s.from_party_id JOIN party pt ON pt.party_id = s.to_party_id
    WHERE ct.batch_id = p_batch ORDER BY ct.seq_no;
BEGIN
  FOR r IN c_trip(3) LOOP
    DBMS_OUTPUT.PUT_LINE('Step ' || r.seq_no || ': ' || r.f || ' -> ' || r.t || ' (' || r.quantity || ')');
  END LOOP;
END;
/

-- 4. FOR UPDATE with WHERE CURRENT OF: mark every active but past-expiry batch as EXPIRED (rolled back)
DECLARE
  CURSOR c_old IS SELECT batch_id FROM batch WHERE batch_status = 'ACTIVE' AND expiry_date < SYSDATE FOR UPDATE;
BEGIN
  FOR r IN c_old LOOP
    UPDATE batch SET batch_status = 'EXPIRED' WHERE CURRENT OF c_old;
  END LOOP;
  ROLLBACK;
END;
/

-- 5. BULK COLLECT into a collection
DECLARE
  TYPE t_names IS TABLE OF party.party_name%TYPE;
  v_names t_names;
BEGIN
  SELECT party_name BULK COLLECT INTO v_names FROM party WHERE license_status <> 'ACTIVE';
  FOR i IN 1 .. v_names.COUNT LOOP DBMS_OUTPUT.PUT_LINE('Not active: ' || v_names(i)); END LOOP;
END;
/

-- 6. REF CURSOR function (the frontend backend can call this)
CREATE OR REPLACE FUNCTION fn_batch_journey(p_batch NUMBER) RETURN SYS_REFCURSOR IS
  v_rc SYS_REFCURSOR;
BEGIN
  OPEN v_rc FOR SELECT seq_no, from_party, to_party, quantity, prev_hash, hash
                FROM v_batch_journey WHERE batch_id = p_batch ORDER BY seq_no;
  RETURN v_rc;
END fn_batch_journey;
/

-- 7. Counterfeit detection: four rules, each driven by a cursor. Alerts are not duplicated.
CREATE OR REPLACE PROCEDURE sp_add_alert(p_type VARCHAR2, p_batch NUMBER, p_unit NUMBER, p_desc VARCHAR2) IS
  v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM alert WHERE alert_type = p_type AND description = p_desc AND alert_status = 'OPEN';
  IF v_n = 0 THEN
    INSERT INTO alert (alert_type, batch_id, unit_id, description) VALUES (p_type, p_batch, p_unit, p_desc);
    DBMS_OUTPUT.PUT_LINE('ALERT ' || p_type || ': ' || p_desc);
  END IF;
END sp_add_alert;
/

CREATE OR REPLACE PROCEDURE sp_detect_counterfeits IS
BEGIN
  -- Rule 1: the same serial written twice with different case or spaces
  FOR r IN (SELECT UPPER(REPLACE(serial_no, ' ', '')) AS s, MIN(unit_id) AS u, MIN(batch_id) AS b
            FROM drug_unit GROUP BY UPPER(REPLACE(serial_no, ' ', '')) HAVING COUNT(*) > 1) LOOP
    sp_add_alert('DUPLICATE_SERIAL', r.b, r.u, 'Serial ' || r.s || ' exists more than once');
  END LOOP;

  -- Rule 2a: pack dispensed by a pharmacy that never received its batch
  FOR r IN (SELECT du.unit_id, du.batch_id, du.serial_no, dr.pharmacy_id
            FROM dispensing_record dr JOIN drug_unit du ON du.unit_id = dr.unit_id
            WHERE NOT EXISTS (SELECT 1 FROM custody_transfer ct JOIN shipment s ON s.shipment_id = ct.shipment_id
                              WHERE ct.batch_id = du.batch_id AND s.to_party_id = dr.pharmacy_id)) LOOP
    sp_add_alert('BROKEN_CHAIN', r.batch_id, r.unit_id,
                 'Pack ' || r.serial_no || ' dispensed by party ' || r.pharmacy_id || ' with no custody record');
  END LOOP;

  -- Rule 2b: a hash or link in the chain does not verify
  FOR r IN (SELECT batch_id, MIN(seq_no) AS seq FROM v_chain_verification
            WHERE hash_status = 'BAD' OR link_status = 'BROKEN' GROUP BY batch_id) LOOP
    sp_add_alert('BROKEN_CHAIN', r.batch_id, NULL, 'Chain of batch ' || r.batch_id || ' fails verification at seq ' || r.seq);
  END LOOP;

  -- Rule 3: shipment with a party whose license was not valid on the dispatch date
  FOR r IN (SELECT DISTINCT ct.batch_id, s.shipment_id, p.party_name
            FROM shipment s JOIN party p ON p.party_id IN (s.from_party_id, s.to_party_id)
                 JOIN custody_transfer ct ON ct.shipment_id = s.shipment_id
            WHERE p.license_status <> 'ACTIVE' OR p.license_expiry < TRUNC(s.dispatch_date)) LOOP
    sp_add_alert('UNAUTHORIZED_SELLER', r.batch_id, NULL, 'Shipment ' || r.shipment_id || ' involves unlicensed party ' || r.party_name);
  END LOOP;

  -- Rule 4: impossible route, different states but delivered in under 6 hours
  FOR r IN (SELECT ct.batch_id, s.shipment_id
            FROM shipment s JOIN party pf ON pf.party_id = s.from_party_id JOIN party pt ON pt.party_id = s.to_party_id
                 JOIN custody_transfer ct ON ct.shipment_id = s.shipment_id
            WHERE pf.state <> pt.state AND s.receive_date IS NOT NULL
              AND s.receive_date - s.dispatch_date < INTERVAL '6' HOUR) LOOP
    sp_add_alert('IMPOSSIBLE_ROUTE', r.batch_id, NULL, 'Shipment ' || r.shipment_id || ' crossed states in under 6 hours');
  END LOOP;
END sp_detect_counterfeits;
/

EXEC sp_detect_counterfeits
SELECT alert_type, description, alert_status FROM alert ORDER BY alert_id;
ROLLBACK;