"""Pharma-Trace API: a thin FastAPI layer over the Oracle schema.
Run:  pip install fastapi uvicorn oracledb
      uvicorn app:app --reload --port 8000
Settings (environment variables): PT_USER, PT_PASSWORD, PT_DSN  (defaults below)
"""
import os

import oracledb
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Pharma-Trace API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

from fastapi.responses import RedirectResponse

@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse("/docs")


def query(sql: str, params: dict | None = None) -> list[dict]:
    with oracledb.connect(
        user=os.getenv("PT_USER", "pharma_trace"),
        password=os.getenv("PT_PASSWORD", "ChangeMe_123"),
        dsn=os.getenv("PT_DSN", "localhost:1521/ORCLPDB.mshome.net"),
    ) as conn, conn.cursor() as cur:
        cur.execute(sql, params or {})
        cols = [d[0].lower() for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


@app.get("/api/batches")
def batches():
    return query(
        """SELECT b.batch_id AS id, b.batch_no AS no, d.drug_name AS drug, b.batch_status AS status
           FROM batch b JOIN drug d ON d.drug_id = b.drug_id ORDER BY b.batch_id"""
    )


@app.get("/api/batches/{batch_id}/journey")
def journey(batch_id: int):
    rows = query(
        """SELECT ct.seq_no, pf.party_name AS from_party, pt.party_name AS to_party, ct.quantity,
                  ct.previous_hash, ct.current_hash, v.hash_status, v.link_status
           FROM custody_transfer ct
             JOIN shipment s ON s.shipment_id = ct.shipment_id
             JOIN party pf ON pf.party_id = s.from_party_id
             JOIN party pt ON pt.party_id = s.to_party_id
             JOIN v_chain_verification v ON v.transfer_id = ct.transfer_id
           WHERE ct.batch_id = :b ORDER BY ct.seq_no""",
        {"b": batch_id},
    )
    return [
        {
            "seq": r["seq_no"],
            "from": r["from_party"],
            "to": r["to_party"],
            "qty": r["quantity"],
            "prev": r["previous_hash"].strip(),
            "hash": r["current_hash"].strip(),
            "hashOk": r["hash_status"] == "OK",
            "linkOk": r["link_status"] == "OK",
        }
        for r in rows
    ]


@app.get("/api/alerts")
def alerts():
    return query(
        """SELECT alert_type AS type, description, alert_status AS status
           FROM alert ORDER BY alert_id DESC"""
    )