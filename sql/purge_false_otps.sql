-- ============================================================
-- MasterMail.ai — Purge false-positive OTPs (years like 2025, 2026)
-- Run this ONCE in MySQL Workbench
-- ============================================================
USE mastermail_db;

SET SQL_SAFE_UPDATES = 0;

-- Delete any OTP entries that are actually years (2020-2039)
DELETE FROM otps WHERE otp_code REGEXP '^20[2-3][0-9]$';

-- Also delete trivially simple codes that aren't real OTPs
DELETE FROM otps WHERE otp_code IN ('0000', '1111', '2222', '3333', '4444',
                                     '5555', '6666', '7777', '8888', '9999',
                                     '1234', '12345', '123456');

SET SQL_SAFE_UPDATES = 1;

SELECT 'False-positive OTPs purged ✅' AS status;
SELECT * FROM otps ORDER BY timestamp DESC LIMIT 20;

