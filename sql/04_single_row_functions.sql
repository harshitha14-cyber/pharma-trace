-- =====================================================================
-- Pharma-Trace | Review 1 | 04_single_row_functions.sql   (Oracle 12c or later)
-- Run AFTER 03_dml_insert.sql. Read-only except the tamper demo (rolled back).
-- Sections: 1 Character | 2 Number | 3 Date | 4 Conversion |
--           5 NULL handling and conditional | 6 Project integrity check
-- =====================================================================

-- ============================ 1. CHARACTER ===========================

-- UPPER, LOWER, INITCAP
SELECT party_name, UPPER(party_name) AS upper_name, LOWER(city) AS city_lower,
       INITCAP(LOWER(party_type)) AS type_initcap
FROM   party ORDER BY party_id;

-- LENGTH, SUBSTR, INSTR on license numbers (e.g. MFG-TN-1001)
SELECT license_no, LENGTH(license_no) AS len,
       SUBSTR(license_no, 1, 3)       AS type_code,
       SUBSTR(license_no, 5, 2)       AS state_code,
       INSTR(license_no, '-')         AS first_dash
FROM   party ORDER BY party_id;

-- Mask a phone number: RPAD + SUBSTR + LENGTH
SELECT party_name, phone,
       RPAD(SUBSTR(phone, 1, 6), LENGTH(phone), '*') AS masked_phone
FROM   party WHERE phone IS NOT NULL;

-- Email domain: nested SUBSTR and INSTR
SELECT email, SUBSTR(email, INSTR(email, '@') + 1) AS email_domain FROM party;

-- Concatenation with || and CONCAT
SELECT party_name || ' (' || party_type || '), ' || city AS party_label,
       CONCAT(city, CONCAT(', ', state)) AS location
FROM   party ORDER BY party_id;

-- REPLACE and LPAD
SELECT serial_no, REPLACE(serial_no, 'SN-', '') AS short_serial,
       LPAD(unit_id, 6, '0') AS padded_unit_id
FROM   drug_unit ORDER BY unit_id;

-- TRIM, LTRIM, RTRIM (demo on dual)
SELECT TRIM('   Dolo 500   ') AS trimmed, LTRIM('xxDolo', 'x') AS ltrimmed,
       RTRIM('Dolo500   ') AS rtrimmed
FROM   dual;

-- Functions in the WHERE clause
SELECT party_name, city FROM party WHERE UPPER(city) = 'CHENNAI';
SELECT party_name FROM party WHERE INSTR(LOWER(party_name), 'pharma') > 0;

-- ============================== 2. NUMBER ============================

SELECT ABS(-12.5) AS abs_val, POWER(2, 8) AS power_val, SQRT(144) AS sqrt_val,
       SIGN(-5) AS sign_val, MOD(10, 3) AS mod_val
FROM   dual;

-- ROUND, TRUNC, CEIL, FLOOR and a Celsius to Fahrenheit conversion
SELECT log_id, temperature_c,
       ROUND(temperature_c)             AS rounded,
       TRUNC(temperature_c)             AS truncated,
       CEIL(temperature_c)              AS ceil_val,
       FLOOR(temperature_c)             AS floor_val,
       ROUND(temperature_c * 9 / 5 + 32, 1) AS temperature_f
FROM   storage_log ORDER BY log_id;

-- Batch size in thousands
SELECT batch_no, quantity_produced, ROUND(quantity_produced / 1000, 1) AS thousands
FROM   batch ORDER BY batch_id;

-- ================================ 3. DATE ============================

SELECT SYSDATE AS today, SYSTIMESTAMP AS now_ts, CURRENT_DATE AS session_today FROM dual;

-- MONTHS_BETWEEN, ADD_MONTHS, LAST_DAY, NEXT_DAY
SELECT batch_no, mfg_date, expiry_date,
       ROUND(MONTHS_BETWEEN(expiry_date, mfg_date)) AS shelf_life_months,
       ADD_MONTHS(mfg_date, 6)                      AS six_month_qc_date,
       LAST_DAY(expiry_date)                        AS expiry_month_end,
       NEXT_DAY(mfg_date, 'MONDAY')                 AS first_monday_after_mfg
FROM   batch ORDER BY batch_id;

-- Days left to expiry and a status label
SELECT batch_no, expiry_date,
       TRUNC(expiry_date - SYSDATE) AS days_to_expiry,
       CASE WHEN expiry_date < SYSDATE                 THEN 'EXPIRED'
            WHEN expiry_date < ADD_MONTHS(SYSDATE, 6)  THEN 'EXPIRING SOON'
            ELSE 'OK' END AS expiry_flag
FROM   batch ORDER BY expiry_date;

-- Transit time: TIMESTAMP minus TIMESTAMP gives an INTERVAL, so use EXTRACT
SELECT shipment_id, dispatch_date, receive_date,
       EXTRACT(DAY    FROM (receive_date - dispatch_date)) * 24
     + EXTRACT(HOUR   FROM (receive_date - dispatch_date))
     + EXTRACT(MINUTE FROM (receive_date - dispatch_date)) / 60 AS transit_hours
FROM   shipment WHERE receive_date IS NOT NULL ORDER BY shipment_id;

-- EXTRACT, TRUNC(date) and ROUND(date)
SELECT dispense_id, dispense_date,
       EXTRACT(YEAR  FROM dispense_date)                AS yr,
       EXTRACT(MONTH FROM dispense_date)                AS mon,
       TO_CHAR(TRUNC(dispense_date, 'MM'), 'DD-Mon-YYYY')   AS month_start,
       TO_CHAR(ROUND(dispense_date, 'YEAR'), 'DD-Mon-YYYY') AS rounded_year
FROM   dispensing_record ORDER BY dispense_id;

-- ============================ 4. CONVERSION ==========================

SELECT dispense_id,
       TO_CHAR(dispense_date, 'DD-Mon-YYYY')        AS formatted_date,
       TO_CHAR(dispense_date, 'DD/MM/YYYY')         AS slash_date,
       TRIM(TO_CHAR(dispense_date, 'Day'))          AS weekday
FROM   dispensing_record ORDER BY dispense_id;

SELECT batch_no, TO_CHAR(quantity_produced, '999,999') AS formatted_qty FROM batch;

-- TO_DATE and TO_NUMBER
SELECT dispense_id, dispense_date
FROM   dispensing_record
WHERE  dispense_date >= TO_DATE('01-03-2026', 'DD-MM-YYYY');

SELECT TO_NUMBER('1500') + 500 AS total_units, TO_CHAR(SYSDATE, 'HH24:MI') AS time_now FROM dual;

-- Patient age from date of birth
SELECT patient_name, dob, TRUNC(MONTHS_BETWEEN(SYSDATE, dob) / 12) AS age_years
FROM   patient ORDER BY patient_id;

-- Dispensing in March only
SELECT dispense_id, dispense_date FROM dispensing_record
WHERE  TO_CHAR(dispense_date, 'MM') = '03';

-- ================= 5. NULL HANDLING AND CONDITIONAL ==================

SELECT dispense_id, prescription_ref,
       NVL(prescription_ref, 'NOT REQUIRED')                       AS rx_or_default,
       NVL2(prescription_ref, 'Prescription on file', 'No prescription') AS rx_status
FROM   dispensing_record ORDER BY dispense_id;

SELECT log_id, shipment_id, NVL(TO_CHAR(shipment_id), 'At rest') AS location_mode
FROM   storage_log ORDER BY log_id;

SELECT party_name, COALESCE(email, phone, 'N/A') AS best_contact FROM party;

SELECT batch_no, NULLIF(batch_status, 'ACTIVE') AS non_active_status FROM batch;

-- DECODE: position of each party type in the supply chain
SELECT party_name, party_type,
       DECODE(party_type, 'MANUFACTURER', 'Level 1',
                          'DISTRIBUTOR',  'Level 2',
                          'WHOLESALER',   'Level 2',
                          'PHARMACY',     'Level 3',
                          'HOSPITAL',     'Level 3', 'Unknown') AS chain_level
FROM   party ORDER BY party_id;

-- CASE: drug storage class and prescription label
SELECT drug_name,
       CASE requires_prescription WHEN 'Y' THEN 'Prescription only' ELSE 'Over the counter' END AS sale_type,
       CASE WHEN max_storage_temp <= 8 THEN 'Cold chain' ELSE 'Room temperature' END           AS storage_class
FROM   drug ORDER BY drug_id;

-- CASE: is the party authorized to trade? (business rule BR8)
SELECT party_name, license_status, license_expiry,
       CASE WHEN license_status <> 'ACTIVE' OR license_expiry < SYSDATE
            THEN 'NOT AUTHORIZED' ELSE 'AUTHORIZED' END AS trading_status
FROM   party ORDER BY party_id;

-- CASE: cold-chain check on the insulin (batch 3) and vaccine (batch 6) logs, range 2 to 8 C
SELECT log_id, batch_id, temperature_c,
       CASE WHEN temperature_c BETWEEN 2 AND 8 THEN 'OK' ELSE 'COLD-CHAIN BREACH' END AS cold_chain_status
FROM   storage_log WHERE batch_id IN (3, 6) ORDER BY log_id;

-- ================== 6. PROJECT INTEGRITY CHECK (HASH) ================

SELECT RAWTOHEX(STANDARD_HASH('Hello', 'SHA256')) AS sha256_demo FROM dual;

-- Recompute each custody hash and compare with the stored one
SELECT transfer_id, batch_id, seq_no,
       CASE WHEN current_hash = RAWTOHEX(STANDARD_HASH(
                 batch_id || '|' || shipment_id || '|' || seq_no || '|' || quantity || '|' || previous_hash,
                 'SHA256'))
            THEN 'VALID' ELSE 'TAMPERED' END AS hash_status
FROM   custody_transfer ORDER BY batch_id, seq_no;

-- Tamper demo: change a quantity, re-run the check, then roll back.
-- This works today because no immutability trigger exists yet (added in Review 2).
UPDATE custody_transfer SET quantity = 9999 WHERE transfer_id = 1;

SELECT transfer_id, batch_id, seq_no, quantity,
       CASE WHEN current_hash = RAWTOHEX(STANDARD_HASH(
                 batch_id || '|' || shipment_id || '|' || seq_no || '|' || quantity || '|' || previous_hash,
                 'SHA256'))
            THEN 'VALID' ELSE 'TAMPERED' END AS hash_status
FROM   custody_transfer WHERE transfer_id = 1;

ROLLBACK;