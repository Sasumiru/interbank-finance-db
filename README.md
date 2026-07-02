# Interbank Finance Database

A containerised PostgreSQL database and Flask API modelling a simplified
interbank network — institutions, accounts, transactions, bilateral
exposures, and risk flags. Built to practice designing and serving a
relational schema for financial data, and to explore the same
"institutions as network nodes, exposures as edges" concept used in
interbank contagion research.

## Stack
PostgreSQL · Docker · Docker Compose · Python (Flask, psycopg2)

## What it models
- **Institutions** — banks, clearing houses, central banks (nodes in the network)
- **Accounts** — settlement, reserve, and trading accounts per institution
- **Transactions** — payments settled between accounts
- **Interbank exposures** — bilateral lending exposure between institutions
  (the edges of the network graph)
- **Risk flags** — concentration risk, large exposure breaches, operational anomalies

## Running it

```bash
git clone <repo-url>
cd interbank-finance-db
docker-compose up --build
```

This starts two containers:
- `db` — PostgreSQL 16, automatically initialised with the schema and seed data
- `api` — Flask API on `http://localhost:5000`

## API Endpoints

| Endpoint | Description |
|---|---|
| `GET /health` | Health check |
| `GET /institutions` | List all institutions |
| `GET /institutions/<id>/accounts` | Accounts held by an institution |
| `GET /exposures` | All bilateral interbank exposures |
| `GET /risk-flags?severity=high` | Risk flags, optionally filtered by severity |
| `GET /integrity-check/large-exposures?threshold=0.02` | Flags any exposure exceeding a configurable share of the lender's Tier 1 capital |

Example:
```bash
curl http://localhost:5000/integrity-check/large-exposures?threshold=0.02
```

## Repo structure
```
finance-db-project/
├── docker-compose.yml
├── db/
│   ├── schema.sql       # Table definitions, constraints, indexes
│   └── seed.sql          # Sample interbank network data
├── api/
│   ├── app.py             # Flask API
│   ├── requirements.txt
│   └── Dockerfile
└── docs/
```

## Design notes
- Exposure and risk-flag tables are deliberately modelled the same way as
  a stress-test dataset (institution-level Tier 1 capital, bilateral
  exposure amounts) so the schema generalises to real regulatory data.
- The `/integrity-check/large-exposures` endpoint applies a simple large-exposure
  rule (exposure as a share of lender's Tier 1 capital) — the same basic logic
  used in bank regulation to flag concentration risk.
- Data integrity is enforced at the database level (foreign keys, CHECK
  constraints e.g. no self-referencing exposures, positive amounts only)
  rather than relying solely on application-layer validation.
