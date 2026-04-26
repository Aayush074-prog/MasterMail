-- ============================================================
-- MasterMail.ai — Fix: Allow same Gmail messages for different users
-- Run this ONCE in MySQL Workbench (use mastermail_db first!)
-- ============================================================

USE mastermail_db;

-- 1. Drop the old constraint that blocks the same message_id across ALL users
ALTER TABLE emails DROP INDEX UNIQUE_MSG_ID;

-- 2. Add the correct constraint: unique per USER, not globally
ALTER TABLE emails ADD CONSTRAINT UNIQUE_USER_MSG UNIQUE (user_id, message_id);

