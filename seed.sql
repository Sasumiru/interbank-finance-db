-- ============================================================
-- Seed data: a small illustrative interbank network
-- ============================================================

INSERT INTO institutions (name, country, institution_type, tier1_capital_musd) VALUES
    ('Alpine National Bank',    'Switzerland', 'commercial_bank',  8200.00),
    ('Nordic Clearing House',   'Sweden',      'clearing_house',   1500.00),
    ('Meridian Investment Bank','Germany',     'investment_bank',  5400.00),
    ('Iberia Central Bank',     'Spain',       'central_bank',    22000.00),
    ('Celtic Commercial Bank',  'Ireland',     'commercial_bank',  3100.00);

INSERT INTO accounts (institution_id, account_type, currency, balance) VALUES
    (1, 'settlement', 'EUR', 120000000.00),
    (1, 'reserve',    'EUR', 450000000.00),
    (2, 'settlement', 'EUR', 80000000.00),
    (3, 'trading',    'EUR', 210000000.00),
    (4, 'reserve',    'EUR', 900000000.00),
    (5, 'settlement', 'EUR', 60000000.00);

INSERT INTO transactions (sender_account_id, receiver_account_id, amount, currency, status) VALUES
    (1, 3, 15000000.00, 'EUR', 'settled'),
    (3, 6, 8000000.00,  'EUR', 'settled'),
    (4, 1, 25000000.00, 'EUR', 'settled'),
    (6, 2, 5000000.00,  'EUR', 'pending'),
    (5, 4, 12000000.00, 'EUR', 'settled');

INSERT INTO interbank_exposures (lender_institution_id, borrower_institution_id, exposure_amount_musd) VALUES
    (1, 3, 150.00),
    (3, 5, 80.00),
    (4, 1, 300.00),
    (5, 2, 45.00),
    (4, 3, 220.00);

INSERT INTO risk_flags (institution_id, flag_type, severity, description) VALUES
    (3, 'large_exposure_breach', 'high',   'Exposure to Iberia Central Bank exceeds 20% of Tier 1 capital'),
    (5, 'concentration_risk',    'medium', 'Over 60% of exposure concentrated in a single counterparty'),
    (1, 'operational_anomaly',   'low',    'Unusual settlement pattern detected in reserve account');
