# Pharma-Trace

**A Blockchain-Inspired Relational Database for Drug Supply Chain Tracking and Counterfeit Medicine Detection**

Domain: Healthcare | Database: Oracle 12c or later (SQL and PL/SQL)

## Abstract

Counterfeit and substandard medicines threaten patient safety because pharmaceutical supply chains lack transparent, tamper-resistant record keeping. Pharma-Trace is a relational database that tracks every drug batch from production to dispensing. Each custody transfer is stored as an append-only record linked to the previous one by a SHA-256 hash, so any change to history can be detected by a verification query. Triggers enforce immutability and flag expired or recalled batches, recursive queries trace a batch's journey, and counterfeit rules detect duplicate serials, broken custody chains, unauthorized sellers and impossible routes.

## Repository structure

```
pharma-trace/
├── README.md
├── docs/
│   ├── 01_problem_analysis.md
│   ├── 02_requirements_rules.md
│   └── 03_entities_attributes.md
├── diagrams/
│   └── er_diagram.png
└── sql/
    ├── 00_drop_all.sql        (teardown, re-run safe)
    ├── 01_ddl.sql             (CREATE, ALTER, DROP, TRUNCATE)
    ├── 02_constraints.sql     (UNIQUE, FOREIGN KEY, CHECK)
    ├── 03_dml_insert.sql      (INSERT, UPDATE, DELETE)
    └── 04_single_row_functions.sql   (single-row and group functions)
```

## How to run (Oracle XE 21c, SQL Developer or SQL*Plus)

1. `sql/00_drop_all.sql` (optional, for a clean start)
2. `sql/01_ddl.sql`
3. `sql/02_constraints.sql`
4. `sql/03_dml_insert.sql`
5. `sql/04_single_row_functions.sql`

## Progress

| Milestone | Status |
|---|---|
| Review 1: analysis, ER/EER, DDL, constraints | completed |
| Review 1: DML, functions, presentation | completed |
| Review 2: subqueries, joins, views, procedures, functions, cursors, triggers | Pending |
| Project report | Pending |
