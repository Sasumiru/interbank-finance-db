-- ============================================================
-- Interbank Finance Database Schema
-- Models a simplified interbank network: institutions, accounts,
-- transactions between institutions, and risk flags derived from
-- exposure concentration.
-- ============================================================

DROP TABLE IF EXISTS risk_flags CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS interbank_exposures CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS institutions CASCADE;

-- ------------------------------------------------------------
-- Institutions: the nodes in the interbank network
-- ------------------------------------------------------------
CREATE TABLE institutions (
    institution_id      SERIAL PRIMARY KEY,
    name                 VARCHAR(100) NOT NULL,
    country               VARCHAR(50) NOT NULL,
    institution_type      VARCHAR(30) NOT NULL CHECK (institution_type IN
                            ('commercial_bank', 'investment_bank', 'central_bank', 'clearing_house')),
    tier1_capital_musd   NUMERIC(14, 2) NOT NULL CHECK (tier1_capital_musd >= 0),
    created_at            TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Accounts: each institution can hold multiple accounts
-- (settlement, reserve, trading)
-- ------------------------------------------------------------
CREATE TABLE accounts (
    account_id           SERIAL PRIMARY KEY,
    institution_id       INTEGER NOT NULL REFERENCES institutions(institution_id) ON DELETE CASCADE,
    account_type          VARCHAR(20) NOT NULL CHECK (account_type IN
                            ('settlement', 'reserve', 'trading')),
    currency               CHAR(3) NOT NULL DEFAULT 'EUR',
    balance                 NUMERIC(16, 2) NOT NULL DEFAULT 0,
    opened_at             TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Transactions: individual payments/settlements between accounts
-- ------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id        SERIAL PRIMARY KEY,
    sender_account_id      INTEGER NOT NULL REFERENCES accounts(account_id),
    receiver_account_id    INTEGER NOT NULL REFERENCES accounts(account_id),
    amount                   NUMERIC(16, 2) NOT NULL CHECK (amount > 0),
    currency                 CHAR(3) NOT NULL DEFAULT 'EUR',
    executed_at             TIMESTAMP NOT NULL DEFAULT NOW(),
    status                   VARCHAR(20) NOT NULL DEFAULT 'settled' CHECK (status IN
                              ('pending', 'settled', 'failed')),
    CONSTRAINT chk_diff_accounts CHECK (sender_account_id <> receiver_account_id)
);

-- ------------------------------------------------------------
-- Interbank exposures: aggregated bilateral exposure between
-- two institutions (i.e. edges of the interbank network graph,
-- the same concept used in the dissertation's network simulation)
-- ------------------------------------------------------------
CREATE TABLE interbank_exposures (
    exposure_id            SERIAL PRIMARY KEY,
    lender_institution_id   INTEGER NOT NULL REFERENCES institutions(institution_id),
    borrower_institution_id INTEGER NOT NULL REFERENCES institutions(institution_id),
    exposure_amount_musd    NUMERIC(14, 2) NOT NULL CHECK (exposure_amount_musd >= 0),
    as_of_date               DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT chk_diff_institutions CHECK (lender_institution_id <> borrower_institution_id)
);

-- ------------------------------------------------------------
-- Risk flags: derived/monitoring table, e.g. concentration risk,
-- large exposure breaches, operational anomalies
-- ------------------------------------------------------------
CREATE TABLE risk_flags (
    flag_id                SERIAL PRIMARY KEY,
    institution_id          INTEGER NOT NULL REFERENCES institutions(institution_id),
    flag_type                VARCHAR(40) NOT NULL CHECK (flag_type IN
                              ('large_exposure_breach', 'concentration_risk',
                               'liquidity_shortfall', 'operational_anomaly')),
    severity                  VARCHAR(10) NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    description                TEXT,
    flagged_at                TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved                   BOOLEAN NOT NULL DEFAULT FALSE
);

-- ------------------------------------------------------------
-- Indexes to support common query patterns
-- ------------------------------------------------------------
CREATE INDEX idx_accounts_institution ON accounts(institution_id);
CREATE INDEX idx_transactions_sender ON transactions(sender_account_id);
CREATE INDEX idx_transactions_receiver ON transactions(receiver_account_id);
CREATE INDEX idx_exposures_lender ON interbank_exposures(lender_institution_id);
CREATE INDEX idx_exposures_borrower ON interbank_exposures(borrower_institution_id);
CREATE INDEX idx_risk_flags_institution ON risk_flags(institution_id);
