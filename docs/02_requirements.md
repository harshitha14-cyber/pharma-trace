# Step 2: Requirements, Users and Business Rules

## Users and roles

| Role | Description | Typical access |
|---|---|---|
| Admin | System administrator | Full DDL/DML, manages users |
| Manufacturer | Produces drugs and creates batches | Insert batches and the first shipment |
| Distributor / Wholesaler | Moves and re-sells stock | Insert custody transfers, update storage logs |
| Pharmacy / Hospital | Receives stock and dispenses to patients | Receive transfers, insert dispensing records |
| Regulator | Oversight and recalls | Read all, flag or recall batches |
| Auditor | Verifies integrity | Read-only on all tables and the audit log |

## Functional requirements

| ID | Requirement |
|---|---|
| FR1 | Register manufacturers, distributors, pharmacies and hospitals |
| FR2 | Register drugs (catalog) and create batches with manufacture and expiry dates |
| FR3 | Assign unique serial numbers to individual units or packs in a batch |
| FR4 | Record shipments between parties |
| FR5 | Record each custody transfer as an append-only entry with a hash linking to the previous entry |
| FR6 | Log storage conditions (temperature, humidity) during transit and storage |
| FR7 | Record dispensing of a drug unit to a patient by a pharmacy |
| FR8 | Trace the full journey of any batch or serial number |
| FR9 | Verify chain integrity and detect tampered records |
| FR10 | Flag expired, recalled or quarantined batches and block their sale |
| FR11 | Detect counterfeit patterns: duplicate serials, broken chains, unauthorized sellers, impossible routes |
| FR12 | Maintain an audit log of every insert, update and delete |
| FR13 | Provide role-based access to data |

## Non-functional requirements

- **Integrity:** transfer history must be immutable and tamper-evident
- **Consistency:** ACID transactions under concurrent updates
- **Performance:** indexed lookups by batch number and serial number
- **Security:** least-privilege access per role
- **Auditability:** every change traceable to a user and a timestamp
- **Normalization:** schema in 3NF/BCNF

## Business rules

| ID | Rule |
|---|---|
| BR1 | Every batch belongs to exactly one drug and one manufacturer |
| BR2 | Expiry date must be later than the manufacture date |
| BR3 | A serial number must be unique within the whole system |
| BR4 | Each custody transfer has exactly one sender and one receiver, and they must be different parties |
| BR5 | The sender of a transfer must be the current holder of the batch (no broken chain) |
| BR6 | Custody records can never be updated or deleted (append-only) |
| BR7 | Each transfer stores `previous_hash` and `current_hash`; the first transfer in a chain uses a genesis hash |
| BR8 | Only parties with an active, valid license may sell or receive drugs |
| BR9 | Expired or recalled batches cannot be transferred or dispensed |
| BR10 | Quantity transferred cannot exceed the quantity currently held |
| BR11 | Temperature-sensitive drugs must stay within their allowed range; a violation raises an alert |
| BR12 | A drug unit can be dispensed only once |
| BR13 | A prescription-only drug requires a prescription reference at dispensing |
| BR14 | A shipment's receive date must not be earlier than its dispatch date |
| BR15 | Every data change is recorded in the audit log |

## Counterfeit detection rules (implemented in Review 2)

1. **Duplicate serial:** the same serial appears in two places, or is dispensed twice
2. **Broken chain:** the sender of a transfer is not the previous receiver
3. **Unauthorized seller:** the party has an expired or revoked license
4. **Impossible route:** two transfers of the same unit in distant places within an impossible time gap

## Assumptions

- Each party has a unique ID and license number
- Hashing uses SHA-256 via Oracle's `STANDARD_HASH`
- Patient data is kept minimal (ID, name, date of birth, gender, phone) for privacy