-- =====================================================================
-- Pharma-Trace | 14_more_sample_data.sql   (run as pharma_trace, after 10_triggers.sql)
-- Adds 4 parties, 3 drugs, 5 patients, 5 batches, 15 packs, 12 hash-linked hand-overs,
-- 10 storage readings (one cold-chain breach) and 6 dispensing records.
-- IDs come from the identity columns; foreign keys are looked up by license, batch or serial.
-- =====================================================================
SET SERVEROUTPUT ON

INSERT INTO party (party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES ('Sri Ganesh Medicals', 'PHARMACY', 'PHR-TN-4004', DATE '2029-02-28', 'Madurai', 'Tamil Nadu', 'shop@sriganesh.example', '+919444000011');
INSERT INTO party (party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES ('Metro Care Hospital', 'HOSPITAL', 'HSP-TN-5002', DATE '2029-08-31', 'Chennai', 'Tamil Nadu', 'pharmacy@metrocare.example', '+919444000012');
INSERT INTO party (party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES ('Southern Cold Logistics', 'DISTRIBUTOR', 'DST-TN-2002', DATE '2029-05-31', 'Chennai', 'Tamil Nadu', 'ops@southerncold.example', '+919444000013');
INSERT INTO party (party_name, party_type, license_no, license_expiry, city, state, email, phone)
VALUES ('Hyderabad Pharma Traders', 'WHOLESALER', 'WHL-TS-3003', DATE '2028-10-31', 'Hyderabad', 'Telangana', 'sales@hydpharma.example', '+919100000014');

INSERT INTO drug (drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
VALUES ('Glycomet 500', 'Metformin', 'TABLET', '500 mg', 'Y', 15, 30);
INSERT INTO drug (drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
VALUES ('Pantocid 40', 'Pantoprazole', 'TABLET', '40 mg', 'Y', 15, 30);
INSERT INTO drug (drug_name, generic_name, dosage_form, strength, requires_prescription, min_storage_temp, max_storage_temp)
VALUES ('TT Vaccine', 'Tetanus toxoid', 'INJECTION', '0.5 ml', 'Y', 2, 8);

INSERT INTO patient (patient_name, dob, gender, phone) VALUES ('Lakshmi Narayanan', DATE '1965-03-14', 'F', '9840066666');
INSERT INTO patient (patient_name, dob, gender, phone) VALUES ('Imran Khan',        DATE '1990-12-02', 'M', '9840077777');
INSERT INTO patient (patient_name, dob, gender, phone) VALUES ('Divya Menon',       DATE '1996-05-21', 'F', '9840088888');
INSERT INTO patient (patient_name, dob, gender, phone) VALUES ('Suresh Babu',       DATE '1972-08-09', 'M', '9840099999');
INSERT INTO patient (patient_name, dob, gender, phone) VALUES ('Anitha Raj',        DATE '1988-02-17', 'F', '9840011122');

INSERT INTO batch (batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
SELECT 'METF-2026-K', d.drug_id, p.party_id, DATE '2026-07-10', DATE '2028-07-09', 6000 FROM drug d, party p
WHERE d.drug_name = 'Glycomet 500' AND p.license_no = 'MFG-MH-1002';
INSERT INTO batch (batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
SELECT 'PANT-2026-L', d.drug_id, p.party_id, DATE '2026-07-25', DATE '2028-07-24', 3500 FROM drug d, party p
WHERE d.drug_name = 'Pantocid 40' AND p.license_no = 'MFG-TN-1001';
INSERT INTO batch (batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
SELECT 'TT-2026-M', d.drug_id, p.party_id, DATE '2026-08-01', DATE '2027-07-31', 1200 FROM drug d, party p
WHERE d.drug_name = 'TT Vaccine' AND p.license_no = 'MFG-MH-1002';
INSERT INTO batch (batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
SELECT 'PARA-2026-N', d.drug_id, p.party_id, DATE '2026-09-01', DATE '2028-08-31', 12000 FROM drug d, party p
WHERE d.drug_name = 'Dolo 500' AND p.license_no = 'MFG-TN-1001';
INSERT INTO batch (batch_no, drug_id, manufacturer_id, mfg_date, expiry_date, quantity_produced)
SELECT 'CET-2026-O', d.drug_id, p.party_id, DATE '2025-12-01', DATE '2026-12-31', 2000 FROM drug d, party p
WHERE d.drug_name = 'Cetzine' AND p.license_no = 'MFG-MH-1002';

-- Packs with serial numbers (3 per new batch)
BEGIN
  FOR r IN (SELECT 'METF-2026-K' bn, 'SN-METF-K-' pf FROM dual UNION ALL SELECT 'PANT-2026-L', 'SN-PANT-L-' FROM dual
            UNION ALL SELECT 'TT-2026-M', 'SN-TT-M-' FROM dual UNION ALL SELECT 'PARA-2026-N', 'SN-PARA-N-' FROM dual
            UNION ALL SELECT 'CET-2026-O', 'SN-CET-O-' FROM dual) LOOP
    FOR i IN 1 .. 3 LOOP
      INSERT INTO drug_unit (serial_no, batch_id) SELECT r.pf || LPAD(i, 4, '0'), batch_id FROM batch WHERE batch_no = r.bn;
    END LOOP;
  END LOOP;
END;
/

-- Hand-overs (hash-linked), storage readings and dispensing
DECLARE
  PROCEDURE add_transfer(p_batch VARCHAR2, p_from VARCHAR2, p_to VARCHAR2, p_qty NUMBER,
                         p_dispatch TIMESTAMP, p_hours NUMBER, p_vehicle VARCHAR2) IS
    v_b NUMBER; v_f NUMBER; v_t NUMBER; v_ship NUMBER; v_seq NUMBER; v_prev VARCHAR2(64);
  BEGIN
    SELECT batch_id INTO v_b FROM batch WHERE batch_no = p_batch;
    SELECT party_id INTO v_f FROM party WHERE license_no = p_from;
    SELECT party_id INTO v_t FROM party WHERE license_no = p_to;
    INSERT INTO shipment (from_party_id, to_party_id, dispatch_date, receive_date, vehicle_no, shipment_status)
    VALUES (v_f, v_t, p_dispatch, p_dispatch + NUMTODSINTERVAL(p_hours, 'HOUR'), p_vehicle, 'DELIVERED')
    RETURNING shipment_id INTO v_ship;
    SELECT NVL(MAX(seq_no), 0) + 1 INTO v_seq FROM custody_transfer WHERE batch_id = v_b;
    IF v_seq = 1 THEN v_prev := RPAD('0', 64, '0');
    ELSE SELECT current_hash INTO v_prev FROM custody_transfer WHERE batch_id = v_b AND seq_no = v_seq - 1;
    END IF;
    INSERT INTO custody_transfer (batch_id, shipment_id, seq_no, quantity, previous_hash, current_hash)
    VALUES (v_b, v_ship, v_seq, p_qty, v_prev, fn_calc_hash(v_b, v_ship, v_seq, p_qty, v_prev));
  END;

  PROCEDURE add_log(p_batch VARCHAR2, p_lic VARCHAR2, p_ts TIMESTAMP, p_temp NUMBER, p_hum NUMBER) IS
  BEGIN
    INSERT INTO storage_log (batch_id, party_id, recorded_at, temperature_c, humidity_pct)
    VALUES ((SELECT batch_id FROM batch WHERE batch_no = p_batch),
            (SELECT party_id FROM party WHERE license_no = p_lic), p_ts, p_temp, p_hum);
  END;

  PROCEDURE add_dispense(p_serial VARCHAR2, p_lic VARCHAR2, p_phone VARCHAR2, p_date DATE, p_rx VARCHAR2) IS
  BEGIN
    INSERT INTO dispensing_record (unit_id, pharmacy_id, patient_id, dispense_date, prescription_ref)
    VALUES ((SELECT unit_id FROM drug_unit WHERE serial_no = p_serial),
            (SELECT party_id FROM party WHERE license_no = p_lic),
            (SELECT patient_id FROM patient WHERE phone = p_phone), p_date, p_rx);
  END;
BEGIN
  -- Metformin: Cipla -> Apex -> two buyers (the chain branches)
  add_transfer('METF-2026-K', 'MFG-MH-1002', 'DST-TN-2001', 3000, TIMESTAMP '2026-07-20 07:00:00', 30, 'MH-12-RS-1111');
  add_transfer('METF-2026-K', 'DST-TN-2001', 'PHR-TN-4004', 1000, TIMESTAMP '2026-07-28 09:00:00', 8,  'TN-38-AB-2201');
  add_transfer('METF-2026-K', 'DST-TN-2001', 'HSP-TN-5002',  800, TIMESTAMP '2026-07-29 09:00:00', 10, 'TN-38-AB-2202');
  -- Pantoprazole: Sun -> MedLine -> Hyderabad -> Sri Ganesh (crosses three states)
  add_transfer('PANT-2026-L', 'MFG-TN-1001', 'WHL-KA-3001', 2000, TIMESTAMP '2026-08-05 06:30:00', 28, 'TN-01-CD-3301');
  add_transfer('PANT-2026-L', 'WHL-KA-3001', 'WHL-TS-3003', 1200, TIMESTAMP '2026-08-10 08:00:00', 20, 'KA-05-EF-3302');
  add_transfer('PANT-2026-L', 'WHL-TS-3003', 'PHR-TN-4004',  500, TIMESTAMP '2026-08-14 07:00:00', 30, 'TS-09-GH-3303');
  -- Tetanus vaccine: cold-chain specialist carries it to a hospital and a pharmacy
  add_transfer('TT-2026-M', 'MFG-MH-1002', 'DST-TN-2002', 600, TIMESTAMP '2026-08-12 05:00:00', 34, 'MH-12-IJ-4401');
  add_transfer('TT-2026-M', 'DST-TN-2002', 'HSP-TN-5002', 300, TIMESTAMP '2026-08-15 06:00:00', 5,  'TN-09-KL-4402');
  add_transfer('TT-2026-M', 'DST-TN-2002', 'PHR-TN-4001', 200, TIMESTAMP '2026-08-16 06:00:00', 6,  'TN-09-KL-4403');
  -- Paracetamol: a long chain of four hand-overs ending at a pharmacy
  add_transfer('PARA-2026-N', 'MFG-TN-1001', 'DST-TN-2001', 5000, TIMESTAMP '2026-09-05 08:00:00', 9,  'TN-01-MN-5501');
  add_transfer('PARA-2026-N', 'DST-TN-2001', 'WHL-KA-3001', 3000, TIMESTAMP '2026-09-10 08:00:00', 22, 'TN-38-OP-5502');
  add_transfer('PARA-2026-N', 'WHL-KA-3001', 'PHR-TN-4002', 1200, TIMESTAMP '2026-09-14 09:00:00', 24, 'KA-05-QR-5503');

  -- Storage readings (the 9.8 C vaccine reading is outside 2 to 8 C and raises a cold-chain alert)
  add_log('METF-2026-K', 'DST-TN-2001', TIMESTAMP '2026-07-21 14:00:00', 24.0, 55);
  add_log('METF-2026-K', 'PHR-TN-4004', TIMESTAMP '2026-07-28 18:00:00', 26.5, 60);
  add_log('PANT-2026-L', 'WHL-KA-3001', TIMESTAMP '2026-08-06 10:00:00', 27.0, 58);
  add_log('PANT-2026-L', 'WHL-TS-3003', TIMESTAMP '2026-08-11 06:00:00', 29.5, 65);
  add_log('TT-2026-M',   'MFG-MH-1002', TIMESTAMP '2026-08-02 09:00:00',  4.5, 40);
  add_log('TT-2026-M',   'DST-TN-2002', TIMESTAMP '2026-08-13 15:00:00',  5.2, 44);
  add_log('TT-2026-M',   'DST-TN-2002', TIMESTAMP '2026-08-15 07:30:00',  9.8, 47);
  add_log('TT-2026-M',   'HSP-TN-5002', TIMESTAMP '2026-08-15 12:00:00',  6.1, 45);
  add_log('TT-2026-M',   'PHR-TN-4001', TIMESTAMP '2026-08-16 13:00:00',  5.9, 43);
  add_log('PARA-2026-N', 'DST-TN-2001', TIMESTAMP '2026-09-06 10:00:00', 25.0, 52);

  -- Dispensing (prescription drugs carry a prescription number; paracetamol does not)
  add_dispense('SN-METF-K-0001', 'PHR-TN-4004', '9840066666', DATE '2026-08-02', 'RX-2026-0301');
  add_dispense('SN-METF-K-0002', 'HSP-TN-5002', '9840077777', DATE '2026-08-05', 'RX-2026-0302');
  add_dispense('SN-PANT-L-0001', 'PHR-TN-4004', '9840088888', DATE '2026-08-20', 'RX-2026-0303');
  add_dispense('SN-TT-M-0001',   'HSP-TN-5002', '9840099999', DATE '2026-08-20', 'RX-2026-0304');
  add_dispense('SN-TT-M-0002',   'PHR-TN-4001', '9840011122', DATE '2026-08-22', 'RX-2026-0305');
  add_dispense('SN-PARA-N-0001', 'PHR-TN-4002', '9840066666', DATE '2026-09-20', NULL);
  COMMIT;
END;
/

-- Check: every chain should still be VALID
SELECT batch_id, fn_verify_chain(batch_id) AS chain_status FROM batch ORDER BY batch_id;
SELECT alert_type, description FROM alert ORDER BY alert_id;   -- shows the new cold-chain alert