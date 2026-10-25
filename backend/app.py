"""Pharma-Trace API: Oracle data, Supabase login, role-based access.

Run:  pip install -r requirements.txt
      set SUPABASE_URL=https://YOUR-PROJECT.supabase.co
      set SUPABASE_ANON_KEY=your-anon-public-key
      set PT_DSN=localhost:1521/ORCLPDB.mshome.net      (and PT_PASSWORD if you changed it)
      uvicorn app:app --reload --port 8000
Supabase proves WHO the person is. The ROLE comes from the Oracle table user_account (matched by email).
There is no update or delete endpoint anywhere: saved records can only be added.
"""
import os
import re
import time

import httpx
import oracledb
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from dotenv import load_dotenv
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")
SEE_ALL = {"ADMIN", "REGULATOR", "AUDITOR"}

app = FastAPI(title="Pharma-Trace API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


def connect():
    return oracledb.connect(
        user=os.getenv("PT_USER", "pharma_trace"),
        password=os.getenv("PT_PASSWORD", "ChangeMe_123"),
        dsn=os.getenv("PT_DSN", "localhost:1521/ORCLPDB.mshome.net"),
    )


def query(sql: str, params: dict | None = None) -> list[dict]:
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params or {})
        cols = [d[0].lower() for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def clean(e: Exception) -> str:
    err = e.args[0] if e.args else e
    first = str(getattr(err, "message", err)).split("\n")[0]
    return re.sub(r"^ORA-\d+:\s*", "", first)


# ---------------------------------------------------------------- login and roles
_cache: dict[str, tuple[float, dict]] = {}


def current_user(authorization: str | None = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Please sign in")
    token = authorization[7:]
    hit = _cache.get(token)
    if hit and hit[0] > time.time():
        return hit[1]
    try:
        r = httpx.get(f"{SUPABASE_URL}/auth/v1/user", timeout=8,
                      headers={"Authorization": f"Bearer {token}", "apikey": SUPABASE_ANON_KEY})
    except httpx.HTTPError:
        raise HTTPException(503, "The login service cannot be reached")
    if r.status_code != 200:
        raise HTTPException(401, "Your login is invalid or has expired")
    email = (r.json().get("email") or "").lower()
    rows = query("SELECT username, role_name, party_id FROM user_account WHERE LOWER(email) = :e AND is_active = 'Y'",
                 {"e": email})
    if not rows:
        raise HTTPException(403, "Your account has no role yet. Ask the administrator.")
    user = {**rows[0], "email": email}
    _cache[token] = (time.time() + 60, user)
    return user


def admin_only(user: dict = Depends(current_user)) -> dict:
    if user["role_name"] != "ADMIN":
        raise HTTPException(403, "Only the administrator can enter data")
    return user


def access(user: dict) -> tuple[str, dict]:
    """SQL condition (on alias b = batch) for the batches this user may see."""
    if user["role_name"] in SEE_ALL:
        return "1 = 1", {}
    return ("(b.manufacturer_id = :p OR EXISTS (SELECT 1 FROM custody_transfer ct "
            "JOIN shipment s ON s.shipment_id = ct.shipment_id "
            "WHERE ct.batch_id = b.batch_id AND :p IN (s.from_party_id, s.to_party_id)))",
            {"p": user["party_id"]})


# ---------------------------------------------------------------- read endpoints
@app.get("/api/health")
def health():
    return {"ok": True}


@app.get("/api/me")
def me(user: dict = Depends(current_user)):
    return {"email": user["email"], "role": user["role_name"], "party": user["party_id"]}


@app.get("/api/batches")
def batches(user: dict = Depends(current_user)):
    w, p = access(user)
    return query(f"""SELECT b.batch_id AS id, b.batch_no AS no, d.drug_name AS drug, b.batch_status AS status
                     FROM batch b JOIN drug d ON d.drug_id = b.drug_id WHERE {w} ORDER BY b.batch_id""", p)


@app.get("/api/batches/{batch_id}/journey")
def journey(batch_id: int, user: dict = Depends(current_user)):
    w, p = access(user)
    if not query(f"SELECT 1 FROM batch b WHERE b.batch_id = :id AND {w}", {"id": batch_id, **p}):
        raise HTTPException(404, "Batch not found or not visible to you")
    rows = query(
        """SELECT ct.seq_no, pf.party_name AS from_party, pt.party_name AS to_party,
                  pf.party_type AS from_type, pt.party_type AS to_type, ct.quantity,
                  ct.previous_hash, ct.current_hash, v.hash_status, v.link_status
           FROM custody_transfer ct
             JOIN shipment s ON s.shipment_id = ct.shipment_id
             JOIN party pf ON pf.party_id = s.from_party_id
             JOIN party pt ON pt.party_id = s.to_party_id
             JOIN v_chain_verification v ON v.transfer_id = ct.transfer_id
           WHERE ct.batch_id = :b ORDER BY ct.seq_no""", {"b": batch_id})
    return [{"seq": r["seq_no"], "from": r["from_party"], "to": r["to_party"], "fromType": r["from_type"],
             "toType": r["to_type"], "qty": r["quantity"], "prev": r["previous_hash"].strip(),
             "hash": r["current_hash"].strip(), "hashOk": r["hash_status"] == "OK",
             "linkOk": r["link_status"] == "OK"} for r in rows]


@app.get("/api/alerts")
def alerts(user: dict = Depends(current_user)):
    w, p = access(user)
    return query(f"""SELECT a.alert_type AS type, a.description, a.alert_status AS status
                     FROM alert a WHERE a.alert_type = 'TAMPER_ATTEMPT'
                        OR a.batch_id IN (SELECT b.batch_id FROM batch b WHERE {w})
                     ORDER BY a.alert_id DESC""", p)


@app.get("/api/integrity")
def integrity(user: dict = Depends(current_user)):
    """Everyone can see this: do all saved records still match their seals?"""
    bad = query("""SELECT batch_id, seq_no FROM v_chain_verification
                   WHERE hash_status = 'BAD' OR link_status = 'BROKEN' ORDER BY batch_id, seq_no""")
    n = query("SELECT COUNT(*) AS n FROM alert WHERE alert_type = 'TAMPER_ATTEMPT' AND alert_status = 'OPEN'")[0]["n"]
    return {"ok": not bad, "problems": bad, "tamper_attempts": n}


@app.get("/api/audit")
def audit(user: dict = Depends(current_user)):
    if user["role_name"] not in SEE_ALL:
        raise HTTPException(403, "The audit log is for administrators, regulators and auditors")
    return query("""SELECT table_name, operation, record_key, old_value, new_value, changed_by, changed_at
                    FROM audit_log ORDER BY audit_id DESC FETCH FIRST 60 ROWS ONLY""")


@app.get("/api/lookups")
def lookups(user: dict = Depends(admin_only)):
    return {
        "parties": query("SELECT party_id AS id, party_name AS name, party_type AS type FROM party ORDER BY party_name"),
        "batches": query("""SELECT b.batch_id AS id, b.batch_no AS no, d.drug_name AS drug FROM batch b
                            JOIN drug d ON d.drug_id = b.drug_id WHERE b.batch_status = 'ACTIVE' ORDER BY b.batch_id"""),
        "units": query("SELECT serial_no AS serial FROM drug_unit WHERE unit_status = 'IN_STOCK' ORDER BY serial_no"),
        "patients": query("SELECT patient_id AS id, patient_name AS name FROM patient ORDER BY patient_name"),
    }

@app.get("/api/config")
def get_public_config():
    return {
        "supabase_url": os.getenv("SUPABASE_URL"),
        "supabase_anon_key": os.getenv("SUPABASE_ANON_KEY")
    }


# ---------------------------------------------------------------- write endpoints (admin only, add-only)
class Transfer(BaseModel):
    batch_id: int
    from_party: int
    to_party: int
    qty: int


class Reading(BaseModel):
    batch_id: int
    party_id: int
    temperature_c: float
    humidity_pct: float | None = None


class Dispense(BaseModel):
    serial: str
    pharmacy_id: int
    patient_id: int
    rx: str | None = None


def run_db(fn):
    try:
        with connect() as conn, conn.cursor() as cur:
            fn(conn, cur)
            conn.commit()
    except oracledb.DatabaseError as e:
        raise HTTPException(400, clean(e))
    return {"saved": True}


@app.post("/api/transfers")
def add_transfer(t: Transfer, user: dict = Depends(admin_only)):
    return run_db(lambda c, cur: cur.callproc("sp_record_transfer", [t.batch_id, t.from_party, t.to_party, t.qty, None]))


@app.post("/api/readings")
def add_reading(r: Reading, user: dict = Depends(admin_only)):
    return run_db(lambda c, cur: cur.execute(
        """INSERT INTO storage_log (batch_id, party_id, recorded_at, temperature_c, humidity_pct)
           VALUES (:b, :p, SYSTIMESTAMP, :t, :h)""",
        {"b": r.batch_id, "p": r.party_id, "t": r.temperature_c, "h": r.humidity_pct}))


@app.post("/api/dispense")
def add_dispense(d: Dispense, user: dict = Depends(admin_only)):
    return run_db(lambda c, cur: cur.callproc("sp_dispense_unit", [d.serial, d.pharmacy_id, d.patient_id, d.rx]))


@app.post("/api/demo/try-edit")
def try_edit(user: dict = Depends(admin_only)):
    """Security demo: try to change a saved record. The database blocks it, logs it and raises an alert."""
    try:
        with connect() as conn, conn.cursor() as cur:
            cur.callproc("dbms_session.set_identifier", [user["email"]])
            cur.execute("UPDATE custody_transfer SET quantity = quantity + 1 "
                        "WHERE transfer_id = (SELECT MIN(transfer_id) FROM custody_transfer)")
            conn.rollback()
    except oracledb.DatabaseError as e:
        return JSONResponse({"blocked": True, "message": clean(e)}, status_code=409)
    raise HTTPException(500, "The edit was NOT blocked. Run 15_auth_and_alerts.sql first.")