# Step 3: Entities, Attributes and Keys

## Entity list (12 tables)

| # | Entity | Purpose |
|---|---|---|
| 1 | PARTY | Every participant: manufacturer, distributor, wholesaler, pharmacy, hospital |
| 2 | DRUG | Drug catalog (what the medicine is) |
| 3 | BATCH | A production lot of a drug |
| 4 | DRUG_UNIT | An individual pack with a unique serial number |
| 5 | SHIPMENT | A movement of goods from one party to another |
| 6 | CUSTODY_TRANSFER | Append-only, hash-linked record of a batch changing hands |
| 7 | STORAGE_LOG | Temperature and humidity readings |
| 8 | PATIENT | Person who receives a dispensed drug |
| 9 | DISPENSING_RECORD | A unit dispensed to a patient by a pharmacy |
| 10 | ALERT | Counterfeit, expiry, recall and cold-chain alerts |
| 11 | AUDIT_LOG | Every insert, update and delete |
| 12 | USER_ACCOUNT | Maps application users to roles and parties (for access control) |

## Attributes and keys (Oracle data types)

### PARTY
| Attribute | Type | Key / Constraint |
|---|---|---|
| party_id | NUMBER | PK (identity) |
| party_name | VARCHAR2(100) | NOT NULL |
| party_type | VARCHAR2(15) | CHECK: MANUFACTURER, DISTRIBUTOR, WHOLESALER, PHARMACY, HOSPITAL |
| license_no | VARCHAR2(30) | UNIQUE, NOT NULL |
| license_status | VARCHAR2(10) | CHECK: ACTIVE, EXPIRED, REVOKED; DEFAULT 'ACTIVE' |
| license_expiry | DATE | NOT NULL |
| city, state | VARCHAR2(50) | |
| email | VARCHAR2(100) | UNIQUE |
| phone | VARCHAR2(20) | widened from 15 by ALTER in 01_ddl.sql |

### DRUG
| Attribute | Type | Key / Constraint |
|---|---|---|
| drug_id | NUMBER | PK |
| drug_name | VARCHAR2(100) | NOT NULL |
| generic_name | VARCHAR2(100) | |
| dosage_form | VARCHAR2(20) | tablet, syrup, injection, etc. |
| strength | VARCHAR2(20) | e.g. 500 mg |
| requires_prescription | CHAR(1) | CHECK Y/N; DEFAULT 'N' |
| min_storage_temp, max_storage_temp | NUMBER(4,1) | CHECK (min < max) |

Composite candidate key: UNIQUE (drug_name, strength, dosage_form). This is a constraint, not a column.

### BATCH
| Attribute | Type | Key / Constraint |
|---|---|---|
| batch_id | NUMBER | PK |
| batch_no | VARCHAR2(30) | NOT NULL |
| drug_id | NUMBER | FK → DRUG |
| manufacturer_id | NUMBER | FK → PARTY |
| mfg_date | DATE | NOT NULL |
| expiry_date | DATE | CHECK (expiry_date > mfg_date) |
| quantity_produced | NUMBER | CHECK (> 0) |
| batch_status | VARCHAR2(12) | CHECK: ACTIVE, RECALLED, QUARANTINED, EXPIRED; DEFAULT 'ACTIVE' |

Composite candidate key: UNIQUE (manufacturer_id, batch_no).

### DRUG_UNIT
| Attribute | Type | Key / Constraint |
|---|---|---|
| unit_id | NUMBER | PK |
| serial_no | VARCHAR2(40) | UNIQUE, NOT NULL |
| batch_id | NUMBER | FK → BATCH |
| unit_status | VARCHAR2(12) | CHECK: IN_STOCK, DISPENSED, FLAGGED; DEFAULT 'IN_STOCK' |

### SHIPMENT
| Attribute | Type | Key / Constraint |
|---|---|---|
| shipment_id | NUMBER | PK |
| from_party_id | NUMBER | FK → PARTY |
| to_party_id | NUMBER | FK → PARTY; CHECK (from ≠ to) |
| dispatch_date | TIMESTAMP | NOT NULL |
| receive_date | TIMESTAMP | CHECK (receive_date >= dispatch_date) |
| vehicle_no | VARCHAR2(20) | |
| shipment_status | VARCHAR2(12) | CHECK: IN_TRANSIT, DELIVERED, REJECTED; DEFAULT 'IN_TRANSIT' |

### CUSTODY_TRANSFER (append-only)
| Attribute | Type | Key / Constraint |
|---|---|---|
| transfer_id | NUMBER | PK |
| batch_id | NUMBER | FK → BATCH |
| shipment_id | NUMBER | FK → SHIPMENT |
| seq_no | NUMBER | position in the batch's chain (1, 2, 3, ...) |
| quantity | NUMBER | CHECK (> 0) |
| previous_hash | CHAR(64) | NOT NULL (genesis = 64 zeros) |
| current_hash | CHAR(64) | NOT NULL, UNIQUE |
| recorded_at | TIMESTAMP | DEFAULT SYSTIMESTAMP |

Composite candidate key: UNIQUE (batch_id, seq_no).

### STORAGE_LOG
| Attribute | Type | Key / Constraint |
|---|---|---|
| log_id | NUMBER | PK |
| batch_id | NUMBER | FK → BATCH |
| party_id | NUMBER | FK → PARTY (where it was stored) |
| shipment_id | NUMBER | FK → SHIPMENT, nullable (set if in transit) |
| recorded_at | TIMESTAMP | NOT NULL |
| temperature_c | NUMBER(4,1) | NOT NULL |
| humidity_pct | NUMBER(4,1) | CHECK (0 to 100) |

### PATIENT
| Attribute | Type | Key / Constraint |
|---|---|---|
| patient_id | NUMBER | PK |
| patient_name | VARCHAR2(100) | NOT NULL |
| dob | DATE | |
| gender | CHAR(1) | CHECK M/F/O |
| phone | VARCHAR2(15) | |

### DISPENSING_RECORD
| Attribute | Type | Key / Constraint |
|---|---|---|
| dispense_id | NUMBER | PK |
| unit_id | NUMBER | FK → DRUG_UNIT, UNIQUE (a unit is dispensed only once) |
| pharmacy_id | NUMBER | FK → PARTY |
| patient_id | NUMBER | FK → PATIENT |
| dispense_date | DATE | DEFAULT SYSDATE |
| prescription_ref | VARCHAR2(30) | required for prescription-only drugs (enforced by trigger in Review 2) |

### ALERT
| Attribute | Type | Key / Constraint |
|---|---|---|
| alert_id | NUMBER | PK |
| alert_type | VARCHAR2(25) | CHECK: DUPLICATE_SERIAL, BROKEN_CHAIN, UNAUTHORIZED_SELLER, IMPOSSIBLE_ROUTE, EXPIRED, RECALLED, COLD_CHAIN |
| batch_id | NUMBER | FK → BATCH, nullable |
| unit_id | NUMBER | FK → DRUG_UNIT, nullable |
| description | VARCHAR2(300) | |
| raised_at | TIMESTAMP | DEFAULT SYSTIMESTAMP |
| alert_status | VARCHAR2(10) | CHECK: OPEN, RESOLVED; DEFAULT 'OPEN' |

At least one of batch_id and unit_id must be filled (CHECK).

### USER_ACCOUNT
| Attribute | Type | Key / Constraint |
|---|---|---|
| user_id | NUMBER | PK |
| username | VARCHAR2(30) | UNIQUE, NOT NULL |
| role_name | VARCHAR2(15) | CHECK: ADMIN, MANUFACTURER, DISTRIBUTOR, PHARMACY, REGULATOR, AUDITOR |
| party_id | NUMBER | FK → PARTY, nullable (admin, regulator, auditor) |
| is_active | CHAR(1) | DEFAULT 'Y' |

### AUDIT_LOG
| Attribute | Type | Key / Constraint |
|---|---|---|
| audit_id | NUMBER | PK |
| table_name | VARCHAR2(30) | NOT NULL |
| operation | VARCHAR2(6) | CHECK: INSERT, UPDATE, DELETE |
| record_key | VARCHAR2(50) | |
| old_value, new_value | VARCHAR2(500) | |
| changed_by | VARCHAR2(30) | DEFAULT USER |
| changed_at | TIMESTAMP | DEFAULT SYSTIMESTAMP |

## Relationships and cardinality

| Relationship | Between | Cardinality |
|---|---|---|
| manufactures | PARTY → BATCH | 1 : N |
| is_of | DRUG → BATCH | 1 : N |
| contains | BATCH → DRUG_UNIT | 1 : N |
| sends | PARTY → SHIPMENT (from) | 1 : N |
| receives | PARTY → SHIPMENT (to) | 1 : N |
| carries | SHIPMENT → CUSTODY_TRANSFER | 1 : N |
| moves | BATCH → CUSTODY_TRANSFER | 1 : N |
| stores | PARTY → STORAGE_LOG | 1 : N |
| monitored_by | BATCH → STORAGE_LOG | 1 : N |
| monitors | SHIPMENT → STORAGE_LOG | 0..1 : N (optional) |
| dispensed_as | DRUG_UNIT → DISPENSING_RECORD | 1 : 0..1 |
| dispenses | PARTY (pharmacy) → DISPENSING_RECORD | 1 : N |
| receives_drug | PATIENT → DISPENSING_RECORD | 1 : N |
| raises | BATCH → ALERT | 1 : N |
| flags | DRUG_UNIT → ALERT | 1 : N |
| belongs_to | PARTY → USER_ACCOUNT | 0..1 : N |

The only many-to-many link is BATCH ↔ SHIPMENT, resolved by CUSTODY_TRANSFER, which carries its own attributes (quantity, hashes).

## EER features

- **Specialization of PARTY:** a disjoint, total specialization into Manufacturer, Distributor, Wholesaler, Pharmacy and Hospital, with `party_type` as the discriminator.
- **Relational mapping:** the specialization is mapped to a single table (PARTY with a discriminator column) instead of five subtype tables, because the subtypes share all their attributes. This avoids empty tables and extra joins.
- **Dependent entities:** CUSTODY_TRANSFER (identified by batch_id + seq_no) and DISPENSING_RECORD depend on their parents.

## Design notes (for the normalization justification)

- Sender and receiver are not stored in CUSTODY_TRANSFER. They are determined by `shipment_id`, so storing them again would break 3NF.
- Transfers are tracked per batch (with quantity), while dispensing is tracked per serial unit. This keeps the hash chain small and still catches duplicate serials at the pharmacy.
- Violation flags are not stored. Cold-chain breaches are derived by comparing `temperature_c` with the drug's min/max range.
- AUDIT_LOG has no foreign keys on purpose, so deleting a business record can never remove its audit history.