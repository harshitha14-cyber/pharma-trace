-- =====================================================================
-- Pharma-Trace | 00_create_user.sql
-- Run ONCE, connected as SYSTEM (in your pluggable database, e.g. XEPDB1).
-- After this, create a new SQL Developer connection with username
-- pharma_trace and run every other script (01 onwards) from that connection.
-- =====================================================================

-- If Oracle complains about the C## prefix, you are in the root container.
-- Switch to the pluggable database first (replace the name if yours differs):
-- ALTER SESSION SET CONTAINER = ORCLPDB;

-- Change the password before you use this anywhere other than your own laptop.
ALTER SESSION SET CONTAINER = ORCLPDB;

CREATE USER pharma_trace IDENTIFIED BY "ChangeMe_123" QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER TO pharma_trace;

-- To start completely fresh later (deletes the user and everything it owns):
-- DROP USER pharma_trace CASCADE;