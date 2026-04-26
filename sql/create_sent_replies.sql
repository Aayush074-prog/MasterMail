-- ═══════════════════════════════════════════════
-- MasterMail: Sent Replies Table
-- Run this ONCE in MySQL Workbench / IntelliJ DB Console
-- ═══════════════════════════════════════════════

USE mastermail_db;

CREATE TABLE IF NOT EXISTS sent_replies (
    reply_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    recipient_email VARCHAR(255) NOT NULL,
    recipient_name VARCHAR(255),
    subject VARCHAR(500),
    message TEXT NOT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Index for fast lookups by user and recipient
CREATE INDEX idx_replies_user ON sent_replies(user_id);
CREATE INDEX idx_replies_recipient ON sent_replies(user_id, recipient_email);

