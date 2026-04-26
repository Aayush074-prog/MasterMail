-- ============================================================
-- MasterMail.ai — Bucket Cleanup & Default Setup
-- Run this ONCE in MySQL Workbench
-- ============================================================
USE mastermail_db;

-- 1. Remove test/junk buckets like "Gaming" that shouldn't be global
--    First remove their rules (FK constraint)
DELETE r FROM bucket_rules r
JOIN buckets b ON r.bucket_id = b.bucket_id
WHERE b.name NOT IN ('Security', 'Personal', 'Work', 'Promotions')
  AND b.user_id IS NULL;

SET SQL_SAFE_UPDATES = 0;

-- Un-assign emails from buckets that will be deleted
UPDATE emails SET bucket_id = NULL
WHERE bucket_id IN (
    SELECT bucket_id FROM buckets
    WHERE name NOT IN ('Security', 'Personal', 'Work', 'Promotions')
      AND user_id IS NULL
);

-- Delete non-default global buckets
DELETE FROM buckets
WHERE name NOT IN ('Security', 'Personal', 'Work', 'Promotions')
  AND user_id IS NULL;

SET SQL_SAFE_UPDATES = 1;

-- 2. Ensure the 4 default buckets exist with user_id = NULL (global)
INSERT INTO buckets (user_id, name)
SELECT NULL, 'Security' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM buckets WHERE name = 'Security' AND user_id IS NULL);

INSERT INTO buckets (user_id, name)
SELECT NULL, 'Personal' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM buckets WHERE name = 'Personal' AND user_id IS NULL);

INSERT INTO buckets (user_id, name)
SELECT NULL, 'Work' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM buckets WHERE name = 'Work' AND user_id IS NULL);

INSERT INTO buckets (user_id, name)
SELECT NULL, 'Promotions' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM buckets WHERE name = 'Promotions' AND user_id IS NULL);

-- 3. Add smart default rules to the 4 core buckets (skip if already exist)
-- Security rules
INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'otp'
FROM buckets b WHERE b.name = 'Security' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'otp');

INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'verification'
FROM buckets b WHERE b.name = 'Security' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'verification');

INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'password'
FROM buckets b WHERE b.name = 'Security' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'password');

INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'login'
FROM buckets b WHERE b.name = 'Security' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'login');

-- Promotions rules
INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'offer'
FROM buckets b WHERE b.name = 'Promotions' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'offer');

INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'discount'
FROM buckets b WHERE b.name = 'Promotions' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'discount');

INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'sale'
FROM buckets b WHERE b.name = 'Promotions' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'sale');

INSERT INTO bucket_rules (bucket_id, rule_type, rule_value)
SELECT b.bucket_id, 'keyword', 'unsubscribe'
FROM buckets b WHERE b.name = 'Promotions' AND b.user_id IS NULL
AND NOT EXISTS (SELECT 1 FROM bucket_rules r WHERE r.bucket_id = b.bucket_id AND r.rule_value = 'unsubscribe');

-- 4. Verify
SELECT b.bucket_id, b.user_id, b.name, r.rule_type, r.rule_value
FROM buckets b LEFT JOIN bucket_rules r ON b.bucket_id = r.bucket_id
WHERE b.user_id IS NULL
ORDER BY b.bucket_id, r.rule_id;

