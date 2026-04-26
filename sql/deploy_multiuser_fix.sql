-- ============================================================
-- MasterMail.ai — Multi-User Fix + Deployment Prep
-- Run this ONCE in MySQL Workbench BEFORE sharing the app
-- ============================================================
USE mastermail_db;

-- 1. SAFELY fix the UNIQUE constraint: must be PER-USER, not global.
--    If user A and user B both get the same email (mailing list),
--    the global constraint blocks user B's sync.

-- Drop old global constraint (might not exist — ignore errors)
SET @idx_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = 'mastermail_db' AND TABLE_NAME = 'emails' AND INDEX_NAME = 'UNIQUE_MSG_ID'
);
SET @drop_sql = IF(@idx_exists > 0, 'ALTER TABLE emails DROP INDEX UNIQUE_MSG_ID', 'SELECT 1');
PREPARE stmt FROM @drop_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Drop composite constraint too (safe to re-run)
SET @idx2_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = 'mastermail_db' AND TABLE_NAME = 'emails' AND INDEX_NAME = 'UNIQUE_USER_MSG'
);
SET @drop_sql2 = IF(@idx2_exists > 0, 'ALTER TABLE emails DROP INDEX UNIQUE_USER_MSG', 'SELECT 1');
PREPARE stmt2 FROM @drop_sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

-- Remove duplicates before adding the constraint (keep the newest)
DELETE e1 FROM emails e1
INNER JOIN emails e2
WHERE e1.email_id < e2.email_id
  AND e1.user_id = e2.user_id
  AND e1.message_id = e2.message_id
  AND e1.message_id IS NOT NULL;

-- Now add the CORRECT per-user unique constraint
ALTER TABLE emails ADD CONSTRAINT UNIQUE_USER_MSG UNIQUE (user_id, message_id);

-- 2. Ensure Gmail credential columns exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS gmail_email VARCHAR(255) NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gmail_app_password VARCHAR(255) NULL;

-- 3. Ensure admin columns exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(10) NOT NULL DEFAULT 'USER';
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login TIMESTAMP NULL;

-- 4. Ensure deleted_emails table exists
CREATE TABLE IF NOT EXISTS deleted_emails (
    email_id INT PRIMARY KEY,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (email_id) REFERENCES emails(email_id) ON DELETE CASCADE
);

-- 5. Ensure otps table exists
CREATE TABLE IF NOT EXISTS otps (
    otp_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    sender_name VARCHAR(500),
    otp_code VARCHAR(10),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 6. Ensure buckets and rules tables exist
CREATE TABLE IF NOT EXISTS buckets (
    bucket_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS bucket_rules (
    rule_id INT AUTO_INCREMENT PRIMARY KEY,
    bucket_id INT NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    rule_value VARCHAR(255) NOT NULL,
    FOREIGN KEY (bucket_id) REFERENCES buckets(bucket_id) ON DELETE CASCADE
);

-- 7. Verify
SELECT 'Multi-user fix applied ✅' AS status;
SELECT user_id, email, gmail_email, role FROM users;

