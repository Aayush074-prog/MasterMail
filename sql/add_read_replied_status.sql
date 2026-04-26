-- Adds read/replied tracking columns to the emails table.
-- Run this once in your MySQL client before deploying the updated code.
-- Safe to re-run: IF NOT EXISTS prevents duplicate-column errors.

ALTER TABLE emails
    ADD COLUMN IF NOT EXISTS is_read    TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_replied TINYINT(1) NOT NULL DEFAULT 0;
