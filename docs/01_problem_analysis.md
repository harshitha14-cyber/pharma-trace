# Step 1: Problem and Domain Analysis

**Domain:** Healthcare / Pharmaceutical Supply Chain

## Background

A medicine travels through many parties before it reaches a patient: manufacturer → distributor → wholesaler → pharmacy or hospital → patient. Each party keeps its own records in a separate system, so no one can verify the full history of a batch end to end.

## Problem statement

Counterfeit and substandard medicines enter the market because supply chain records are fragmented, editable and not linked to each other. Once a record is altered or deleted, there is no way to detect it. This leads to:

- Fake or duplicate-serial drugs reaching patients
- Expired or recalled batches still being sold
- Broken custody (a batch appears at a pharmacy with no record of how it got there)
- Cold-chain violations (for example, vaccines stored at the wrong temperature) going unnoticed
- Slow, manual recall and investigation processes

## Why this matters

- The WHO reports that a significant share of medical products in low- and middle-income countries are substandard or falsified.
- Patient safety, legal liability and brand trust are all at stake.

## Existing approaches and their gaps

| Approach | Gap |
|---|---|
| Paper or separate-system records | Easy to tamper with, no cross-party verification |
| Full blockchain | High cost, low query flexibility, poor performance for analytics |
| Plain relational database | Mutable by default, with no tamper detection |

## Proposed solution

Pharma-Trace is a relational database that borrows blockchain ideas: every custody transfer is an append-only record linked to the previous one by a hash. It keeps the speed, SQL power and maturity of an RDBMS.

## Objectives

1. Track every drug batch from production to dispensing.
2. Make history tamper-evident through hash-linked custody records.
3. Detect counterfeit patterns (duplicate serials, broken chains, unauthorized sellers, impossible routes).
4. Enforce expiry, recall and storage-condition rules automatically.
5. Maintain a full audit trail and role-based access.

## Scope

- **In scope:** manufacturers, batches, shipments, custody transfers, storage conditions, pharmacies, dispensing records, audit logs.
- **Out of scope:** real payment processing, a real blockchain network, and a production-grade user interface.

## Stakeholders

Manufacturer, Distributor/Wholesaler, Pharmacy/Hospital, Drug Regulator, Patient, System Admin.