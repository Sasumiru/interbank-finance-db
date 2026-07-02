"""
Finance Interbank Database — API layer

A small Flask API sitting on top of the PostgreSQL interbank database.
Exposes endpoints to query institutions, exposures, and risk flags, and
includes a basic data-integrity check endpoint (e.g. flags any exposure
that exceeds a configurable share of an institution's Tier 1 capital,
similar to the large-exposure logic used in bank stress testing).
"""

import os
import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "db"),
    "port": os.environ.get("DB_PORT", "5432"),
    "dbname": os.environ.get("DB_NAME", "finance_db"),
    "user": os.environ.get("DB_USER", "finance_user"),
    "password": os.environ.get("DB_PASSWORD", "finance_pass"),
}


def get_connection():
    return psycopg2.connect(**DB_CONFIG)


@app.route("/health", methods=["GET"])
def health():
    """Basic health check endpoint."""
    return jsonify({"status": "ok"})


@app.route("/institutions", methods=["GET"])
def list_institutions():
    """Return all institutions in the network."""
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM institutions ORDER BY institution_id;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/institutions/<int:institution_id>/accounts", methods=["GET"])
def get_institution_accounts(institution_id):
    """Return all accounts held by a given institution."""
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        "SELECT * FROM accounts WHERE institution_id = %s ORDER BY account_id;",
        (institution_id,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/exposures", methods=["GET"])
def list_exposures():
    """Return all interbank exposures, i.e. the edges of the network graph."""
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        """
        SELECT e.exposure_id,
               l.name AS lender,
               b.name AS borrower,
               e.exposure_amount_musd,
               e.as_of_date
        FROM interbank_exposures e
        JOIN institutions l ON e.lender_institution_id = l.institution_id
        JOIN institutions b ON e.borrower_institution_id = b.institution_id
        ORDER BY e.exposure_amount_musd DESC;
        """
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/risk-flags", methods=["GET"])
def list_risk_flags():
    """Return all risk flags, optionally filtered by severity via ?severity=high."""
    severity = request.args.get("severity")
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    if severity:
        cur.execute(
            """
            SELECT rf.*, i.name AS institution_name
            FROM risk_flags rf
            JOIN institutions i ON rf.institution_id = i.institution_id
            WHERE rf.severity = %s
            ORDER BY rf.flagged_at DESC;
            """,
            (severity,),
        )
    else:
        cur.execute(
            """
            SELECT rf.*, i.name AS institution_name
            FROM risk_flags rf
            JOIN institutions i ON rf.institution_id = i.institution_id
            ORDER BY rf.flagged_at DESC;
            """
        )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/integrity-check/large-exposures", methods=["GET"])
def check_large_exposures():
    """
    Data integrity / risk check: flags any borrower whose total exposure
    exceeds a configurable threshold (default 25%) of the LENDER's Tier 1
    capital. Mirrors the "large exposure" concept used in bank regulation
    and stress testing.
    """
    threshold = float(request.args.get("threshold", 0.25))

    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        """
        SELECT e.exposure_id,
               l.name AS lender,
               l.tier1_capital_musd,
               b.name AS borrower,
               e.exposure_amount_musd,
               ROUND(e.exposure_amount_musd / l.tier1_capital_musd, 4) AS exposure_ratio
        FROM interbank_exposures e
        JOIN institutions l ON e.lender_institution_id = l.institution_id
        JOIN institutions b ON e.borrower_institution_id = b.institution_id
        WHERE e.exposure_amount_musd / l.tier1_capital_musd > %s
        ORDER BY exposure_ratio DESC;
        """,
        (threshold,),
    )
    breaches = cur.fetchall()
    cur.close()
    conn.close()

    return jsonify({
        "threshold": threshold,
        "breach_count": len(breaches),
        "breaches": breaches,
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
