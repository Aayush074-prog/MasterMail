-- ============================================================
-- MasterMail.ai — Admin Dashboard Migration Script
-- Run this ONCE in your IntelliJ Database Console (MySQL)
-- ============================================================

-- 1. Add 'role' column to users table (default USER, ADMIN for admin accounts)
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(10) NOT NULL DEFAULT 'USER';

-- 2. Add 'last_login' column to track active users
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login TIMESTAMP NULL;

-- 3. Promote your main account to ADMIN
--    (Change the email to match YOUR admin account)
UPDATE users SET role = 'ADMIN' WHERE email = 'aayush.das@mitwpu.edu.in';

-- 4. Verify the changes
SELECT user_id, name, email, role, last_login FROM users;

