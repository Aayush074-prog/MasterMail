-- ============================================================
-- MasterMail.ai — Per-User Gmail Credentials
-- Run this ONCE in MySQL Workbench (safe to re-run)
-- ============================================================
USE mastermail_db;

-- Safe: won't error if columns already exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS gmail_email VARCHAR(255) NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gmail_app_password VARCHAR(255) NULL;

-- Pre-fill the admin account so it keeps working
UPDATE users SET gmail_email = 'aayush.das@mitwpu.edu.in',
                 gmail_app_password = 'oxkr gjxs mivs upyn'
WHERE email = 'aayush.das@mitwpu.edu.in';
