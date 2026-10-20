-- =====================================================================
-- Pharma-Trace | 00_drop_all.sql
-- Drops every table so you can re-run the scripts from scratch.
-- CASCADE CONSTRAINTS removes foreign keys; PURGE skips the recycle bin.
-- Safe to run even if a table does not exist yet (errors can be ignored).
-- =====================================================================

DROP TABLE alert             CASCADE CONSTRAINTS PURGE;
DROP TABLE dispensing_record CASCADE CONSTRAINTS PURGE;
DROP TABLE storage_log       CASCADE CONSTRAINTS PURGE;
DROP TABLE custody_transfer  CASCADE CONSTRAINTS PURGE;
DROP TABLE drug_unit         CASCADE CONSTRAINTS PURGE;
DROP TABLE shipment          CASCADE CONSTRAINTS PURGE;
DROP TABLE batch             CASCADE CONSTRAINTS PURGE;
DROP TABLE user_account      CASCADE CONSTRAINTS PURGE;
DROP TABLE patient           CASCADE CONSTRAINTS PURGE;
DROP TABLE drug              CASCADE CONSTRAINTS PURGE;
DROP TABLE party             CASCADE CONSTRAINTS PURGE;
DROP TABLE audit_log         CASCADE CONSTRAINTS PURGE;
DROP TABLE scratch_demo      CASCADE CONSTRAINTS PURGE;