-- =====================================================================
-- Pharma-Trace | Review 2 | 11_rbac.sql   (Role-based access control)
-- Run as SYSTEM (not pharma_trace). Replace ORCLPDB if your PDB name differs.
-- Run AFTER 10_triggers.sql so every object exists.
-- =====================================================================
ALTER SESSION SET CONTAINER = ORCLPDB;

CREATE ROLE r_admin;
CREATE ROLE r_manufacturer;
CREATE ROLE r_distributor;
CREATE ROLE r_pharmacy;
CREATE ROLE r_regulator;
CREATE ROLE r_auditor;

-- Everyone can log in
GRANT CREATE SESSION TO r_admin, r_manufacturer, r_distributor, r_pharmacy, r_regulator, r_auditor;

-- Admin: full access to the data tables
GRANT SELECT, INSERT, UPDATE, DELETE ON pharma_trace.party        TO r_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON pharma_trace.drug         TO r_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON pharma_trace.user_account TO r_admin;
GRANT SELECT ON pharma_trace.audit_log TO r_admin;

-- Manufacturer: create batches through the view, move stock through the procedure
GRANT SELECT, INSERT ON pharma_trace.v_active_batches  TO r_manufacturer;
GRANT SELECT         ON pharma_trace.drug              TO r_manufacturer;
GRANT SELECT         ON pharma_trace.v_batch_overview  TO r_manufacturer, r_distributor, r_pharmacy, r_regulator, r_auditor;
GRANT SELECT         ON pharma_trace.v_batch_journey   TO r_manufacturer, r_distributor, r_pharmacy, r_regulator, r_auditor;
GRANT EXECUTE        ON pharma_trace.sp_record_transfer TO r_manufacturer, r_distributor;

-- Pharmacy: dispense and look at its own dispensing view (no patient details)
GRANT EXECUTE ON pharma_trace.sp_dispense_unit    TO r_pharmacy;
GRANT SELECT  ON pharma_trace.v_pharmacy_dispensing TO r_pharmacy;

-- Regulator: read everything useful, recall batches, run counterfeit checks
GRANT SELECT  ON pharma_trace.v_open_alerts        TO r_regulator, r_auditor;
GRANT SELECT  ON pharma_trace.v_cold_chain_breaches TO r_regulator, r_auditor;
GRANT SELECT  ON pharma_trace.v_expiring_batches   TO r_regulator, r_auditor;
GRANT SELECT  ON pharma_trace.v_party_authorization TO r_regulator, r_auditor;
GRANT EXECUTE ON pharma_trace.sp_recall_batch          TO r_regulator;
GRANT EXECUTE ON pharma_trace.sp_detect_counterfeits   TO r_regulator;

-- Auditor: read-only, including the audit log and chain verification
GRANT SELECT  ON pharma_trace.audit_log            TO r_auditor;
GRANT SELECT  ON pharma_trace.v_chain_verification TO r_auditor, r_regulator;
GRANT EXECUTE ON pharma_trace.fn_verify_chain      TO r_auditor, r_regulator;

-- Demo users (change the passwords)
CREATE USER u_regulator IDENTIFIED BY "ChangeMe_123";
CREATE USER u_pharmacy  IDENTIFIED BY "ChangeMe_123";
CREATE USER u_auditor   IDENTIFIED BY "ChangeMe_123";
GRANT r_regulator TO u_regulator;
GRANT r_pharmacy  TO u_pharmacy;
GRANT r_auditor   TO u_auditor;

-- Check what a role can do
SELECT grantee, table_name, privilege FROM dba_tab_privs
WHERE  grantee LIKE 'R\_%' ESCAPE '\' ORDER BY grantee, table_name;

-- Test: connect as u_pharmacy and try
--   SELECT * FROM pharma_trace.audit_log;                       -> ORA-00942 (no access)
--   EXEC pharma_trace.sp_recall_batch(1, 'test');               -> ORA-06550/ORA-00942 (not allowed)
--   SELECT * FROM pharma_trace.v_pharmacy_dispensing;           -> works
