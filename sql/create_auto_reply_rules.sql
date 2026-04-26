-- ============================================================
-- MasterMail.ai — Custom Auto-Reply Rules
-- Run this ONCE in MySQL Workbench (safe to re-run)
-- ============================================================
USE mastermail_db;

-- Create table for custom auto-reply rules
CREATE TABLE IF NOT EXISTS auto_reply_rules (
    rule_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    keyword VARCHAR(255) NOT NULL COMMENT 'Trigger keyword (e.g., "happy birthday")',
    reply_message TEXT NOT NULL COMMENT 'Auto-generated reply draft',
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Enable/disable rule',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_active (user_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create table for auto-drafted replies (not sent, just drafted)
CREATE TABLE IF NOT EXISTS auto_drafted_replies (
    draft_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    email_id INT NOT NULL COMMENT 'The incoming email that triggered the draft',
    rule_id INT NOT NULL COMMENT 'Which rule triggered this draft',
    recipient_email VARCHAR(255) NOT NULL,
    recipient_name VARCHAR(255),
    subject VARCHAR(500),
    draft_message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (email_id) REFERENCES emails(email_id) ON DELETE CASCADE,
    FOREIGN KEY (rule_id) REFERENCES auto_reply_rules(rule_id) ON DELETE CASCADE,
    UNIQUE KEY unique_draft (email_id, rule_id) COMMENT 'Prevent duplicate drafts for same email+rule'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert default rule: "happy birthday" → "Thank you so much!"
-- This will be added for existing users, but new users get it via registration
INSERT IGNORE INTO auto_reply_rules (user_id, keyword, reply_message, is_active)
SELECT user_id, 'happy birthday', 'Thank you so much!', TRUE
FROM users
WHERE NOT EXISTS (
    SELECT 1 FROM auto_reply_rules
    WHERE auto_reply_rules.user_id = users.user_id
    AND auto_reply_rules.keyword = 'happy birthday'
);
