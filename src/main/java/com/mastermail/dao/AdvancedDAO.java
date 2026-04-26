package com.mastermail.dao;

import com.mastermail.util.DBConnection;
import com.mastermail.model.*;
import com.mastermail.service.GeminiCategorizationService;
import jakarta.mail.*;
import jakarta.mail.internet.*;
import jakarta.mail.FetchProfile;
import jakarta.mail.Flags;
import jakarta.mail.search.HeaderTerm;
import java.util.Properties;

import java.sql.*;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class AdvancedDAO {

    // =========================================================================
    // SECTION 1: AUTHENTICATION
    // =========================================================================

    public boolean emailExists(String email) {
        String sql = "SELECT 1 FROM users WHERE email = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email);
            return ps.executeQuery().next();
        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        }
    }

    public boolean updatePassword(String email, String newPassword) {
        String sql = "UPDATE users SET password = ? WHERE email = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, newPassword);
            ps.setString(2, email);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        }
    }

    public boolean registerUser(String name, String email, String password) {
        String sql = "INSERT INTO users (name, email, password) VALUES (?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, name);
            ps.setString(2, email);
            ps.setString(3, password);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        }
    }

    public User loginUser(String email, String password) {
        String sql = "SELECT * FROM users WHERE email = ? AND password = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email);
            ps.setString(2, password);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                int userId = rs.getInt("user_id");
                String name = rs.getString("name");
                String userEmail = rs.getString("email");

                // Safely read admin columns — they may not exist yet
                String role = "USER";
                String lastLogin = null;
                try {
                    role = rs.getString("role");
                    if (role == null) role = "USER";
                } catch (SQLException ignored) {
                    System.out.println("[LOGIN] 'role' column not found — defaulting to USER");
                }
                try {
                    lastLogin = rs.getString("last_login");
                } catch (SQLException ignored) {
                    System.out.println("[LOGIN] 'last_login' column not found — skipping");
                }

                // Stamp last_login on every successful authentication
                try (PreparedStatement upd = conn.prepareStatement(
                        "UPDATE users SET last_login = NOW() WHERE user_id = ?")) {
                    upd.setInt(1, userId);
                    upd.executeUpdate();
                } catch (SQLException ignored) {
                    // last_login column might not exist yet — non-fatal
                }

                System.out.println("[LOGIN] Success: " + userEmail + " | role=" + role);
                User user = new User(userId, name, userEmail, role, lastLogin);

                // Load Gmail sync credentials if they exist
                try {
                    user.setGmailEmail(rs.getString("gmail_email"));
                    user.setGmailAppPassword(rs.getString("gmail_app_password"));
                } catch (SQLException ignored) {
                    System.out.println("[LOGIN] gmail credential columns not found — skipping");
                }

                return user;
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return null;
    }

    // =========================================================================
    // SECTION 2: EMAIL CRUD & INBOX
    // =========================================================================

    /** Save or update a user's Gmail IMAP credentials for sync. */
    public boolean saveGmailCredentials(int userId, String gmailEmail, String appPassword) {
        String sql = "UPDATE users SET gmail_email = ?, gmail_app_password = ? WHERE user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, gmailEmail);
            ps.setString(2, appPassword);
            ps.setInt(3, userId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.out.println("[GMAIL] Failed to save credentials for user_id=" + userId);
            e.printStackTrace();
            return false;
        }
    }

    /** Mark an email as read. Called when the user opens an email card. */
    public void markEmailRead(int emailId, int userId) {
        String sql = "UPDATE emails SET is_read = TRUE WHERE email_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, emailId);
            ps.setInt(2, userId);
            ps.executeUpdate();
        } catch (SQLException e) { e.printStackTrace(); }
    }

    /** Mark an email as replied (and implicitly read). Called after a reply is sent. */
    public void markEmailReplied(int emailId, int userId) {
        String sql = "UPDATE emails SET is_replied = TRUE, is_read = TRUE WHERE email_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, emailId);
            ps.setInt(2, userId);
            ps.executeUpdate();
        } catch (SQLException e) { e.printStackTrace(); }
    }

    /** Returns the RFC-822 message_id stored for a given email row. */
    public String getMessageIdByEmailId(int emailId, int userId) {
        String sql = "SELECT message_id FROM emails WHERE email_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, emailId);
            ps.setInt(2, userId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getString("message_id");
        } catch (SQLException e) { e.printStackTrace(); }
        return null;
    }

    /**
     * Opens a READ_WRITE IMAP connection to Gmail and sets the \Seen flag
     * on the message identified by messageId. All errors are logged and swallowed —
     * MySQL is already updated before this is called, so IMAP failure is degraded mode.
     */
    public void setGmailMessageSeen(String gmailEmail, String appPassword, String messageId) {
        if (messageId == null || messageId.isBlank()) return;

        // Synthetic fallback IDs ("sender|subject|date") have no corresponding IMAP header.
        // Real RFC-822 Message-IDs always contain '@' (inside angle brackets) or start with '<'.
        if (!messageId.contains("@") && !messageId.startsWith("<")) {
            System.out.println("[IMAP-SEEN] Skipping synthetic message_id: " + messageId);
            return;
        }

        Properties props = new Properties();
        props.put("mail.imaps.host", "imap.gmail.com");
        props.put("mail.imaps.port", "993");
        props.put("mail.imaps.ssl.enable", "true");
        props.put("mail.imaps.connectiontimeout", "8000");
        props.put("mail.imaps.timeout", "8000");

        Store store = null;
        Folder inbox = null;
        try {
            Session session = Session.getInstance(props);
            store = session.getStore("imaps");
            store.connect("imap.gmail.com", gmailEmail, appPassword);

            inbox = store.getFolder("INBOX");
            inbox.open(Folder.READ_WRITE);  // READ_WRITE required to set flags

            // Server-side SEARCH HEADER — efficient, no client-side iteration
            Message[] found = inbox.search(new HeaderTerm("Message-ID", messageId));
            if (found == null || found.length == 0) {
                System.out.println("[IMAP-SEEN] Not found in INBOX (archived/moved?): " + messageId);
                return;
            }
            found[0].setFlag(Flags.Flag.SEEN, true);
            System.out.println("[IMAP-SEEN] \\Seen set on Gmail: " + messageId);

        } catch (AuthenticationFailedException e) {
            System.out.println("[IMAP-SEEN] Auth failed — MySQL already updated. " + e.getMessage());
        } catch (Exception e) {
            System.out.println("[IMAP-SEEN] Non-fatal error: " + e.getClass().getSimpleName() + " — " + e.getMessage());
        } finally {
            // false = do NOT expunge deleted messages — matches existing syncGmail pattern
            try { if (inbox != null && inbox.isOpen()) inbox.close(false); } catch (Exception ignored) {}
            try { if (store != null && store.isConnected()) store.close(); } catch (Exception ignored) {}
        }
    }

    /** Fetch all non-deleted emails for the logged-in user. */
    public List<Email> getEmails(int userId) {
        return getEmailsPage(userId, 1, Integer.MAX_VALUE);
    }

    public List<Email> getEmailsPage(int userId, int page, int pageSize) {
        List<Email> list = new ArrayList<>();
        int offset = (page - 1) * pageSize;
        String query = "SELECT e.*, b.name AS bucket_name FROM emails e "
                + "LEFT JOIN buckets b ON e.bucket_id = b.bucket_id "
                + "LEFT JOIN deleted_emails d ON e.email_id = d.email_id "
                + "WHERE e.user_id = ? AND d.email_id IS NULL "
                + "ORDER BY e.created_at DESC LIMIT ? OFFSET ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, userId);
            ps.setInt(2, pageSize);
            ps.setInt(3, offset);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                list.add(new Email(rs.getInt("email_id"),
                        rs.getString("sender_name"),
                        rs.getString("subject"),
                        rs.getString("body"),
                        rs.getString("category"),
                        rs.getString("created_at"),
                        rs.getString("bucket_name"),
                        rs.getBoolean("is_read"),
                        rs.getBoolean("is_replied")));
            }
        } catch (SQLException e) {
            System.out.println("[getEmailsPage] SQL ERROR: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    public int countEmails(int userId) {
        String query = "SELECT COUNT(*) FROM emails e "
                + "LEFT JOIN deleted_emails d ON e.email_id = d.email_id "
                + "WHERE e.user_id = ? AND d.email_id IS NULL";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getInt(1);
        } catch (SQLException e) {
            System.out.println("[countEmails] SQL ERROR: " + e.getMessage());
        }
        return 0;
    }

    /**
     * Removes orphaned deleted_emails entries that point to email_ids
     * no longer present in the emails table (e.g. after TRUNCATE).
     */
    public void cleanOrphanedDeletes() {
        String sql = "DELETE d FROM deleted_emails d " +
                "LEFT JOIN emails e ON d.email_id = e.email_id " +
                "WHERE e.email_id IS NULL";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            int removed = ps.executeUpdate();
            if (removed > 0) {
                System.out.println("🧹 [CLEANUP] Removed " + removed + " orphaned deleted_emails entries.");
            }
        } catch (SQLException e) { e.printStackTrace(); }
    }

    /** Add a new email with auto-categorization via bucket rules. */
    public void addEmail(int userId, String sender, String subject, String body) {
        int bucketId = resolveBucketId(userId, sender, subject);
        List<String[]> rules = getFeedbackRules(userId);
        String category = GeminiCategorizationService.categorize(userId, sender, subject, body, rules);

        String sql = "INSERT INTO emails (user_id, sender_name, subject, body, category, bucket_id) VALUES (?, ?, ?, ?, ?, ?)";
        int emailId = -1;
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, userId);
            ps.setString(2, sender);
            ps.setString(3, subject);
            ps.setString(4, body);
            ps.setString(5, category);
            if (bucketId > 0) ps.setInt(6, bucketId); else ps.setNull(6, Types.INTEGER);
            ps.executeUpdate();

            // Get the generated email_id
            ResultSet rs = ps.getGeneratedKeys();
            if (rs.next()) {
                emailId = rs.getInt(1);
            }
        } catch (SQLException e) { e.printStackTrace(); }

        // Extract & store any OTP found in the body
        extractAndStoreOTP(userId, sender, body);

        // Process auto-reply rules
        if (emailId > 0) {
            processAutoReply(userId, emailId, sender, sender, subject, body);
        }
    }

    // =========================================================================
    // SECTION 3: BUCKET MANAGEMENT
    // =========================================================================

    /** Create a new custom bucket AND return its generated ID. */
    public int createBucketAndReturnId(int userId, String name) {
        String sql = "INSERT INTO buckets (user_id, name) VALUES (?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, userId);
            ps.setString(2, name);
            ps.executeUpdate();
            ResultSet rs = ps.getGeneratedKeys();
            if (rs.next()) return rs.getInt(1);
        } catch (SQLException e) { e.printStackTrace(); }
        return -1;
    }

    /**
     * Returns default buckets (user_id IS NULL) + this user's custom buckets.
     * Each bucket-rule pair is a separate row (for the table display).
     */
    public List<Bucket> getBuckets(int userId) {
        List<Bucket> list = new ArrayList<>();
        String sql = "SELECT b.bucket_id, b.user_id, b.name, r.rule_type, r.rule_value " +
                "FROM buckets b LEFT JOIN bucket_rules r ON b.bucket_id = r.bucket_id " +
                "WHERE b.user_id IS NULL OR b.user_id = ? " +
                "ORDER BY b.user_id IS NULL DESC, b.bucket_id, r.rule_id";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                int bucketUserId = rs.getInt("user_id");
                if (rs.wasNull()) bucketUserId = 0;  // NULL → 0 = default
                Bucket b = new Bucket(rs.getInt("bucket_id"), bucketUserId, rs.getString("name"));
                b.setRuleType(rs.getString("rule_type"));
                b.setRulePattern(rs.getString("rule_value"));
                list.add(b);
            }
        } catch (SQLException e) { e.printStackTrace(); }
        return list;
    }

    /**
     * Deletes a custom bucket (and cascades to its rules).
     * Only allows deleting user-created buckets, NOT global defaults.
     * @return true if deleted, false if it was a default or not found.
     */
    public boolean deleteBucket(int bucketId, int userId) {
        // First, un-assign any emails that were in this bucket
        String unassign = "UPDATE emails SET bucket_id = NULL WHERE bucket_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(unassign)) {
            ps.setInt(1, bucketId);
            ps.executeUpdate();
        } catch (SQLException e) { e.printStackTrace(); }

        // Delete the bucket itself (only if it belongs to this user, not a default)
        String sql = "DELETE FROM buckets WHERE bucket_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bucketId);
            ps.setInt(2, userId);
            int rows = ps.executeUpdate();
            System.out.println("🗑️ [BUCKET] Delete bucket_id=" + bucketId + " for user_id=" + userId + " → " + (rows > 0 ? "DELETED" : "BLOCKED (default or not found)"));
            return rows > 0;
        } catch (SQLException e) { e.printStackTrace(); }
        return false;
    }

    /** Add a sorting rule to an existing bucket. */
    public void addRule(int bucketId, String type, String value) {
        String sql = "INSERT INTO bucket_rules (bucket_id, rule_type, rule_value) VALUES (?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bucketId);
            ps.setString(2, type);
            ps.setString(3, value);
            ps.executeUpdate();
        } catch (SQLException e) { e.printStackTrace(); }
    }

    // =========================================================================
    // SECTION 4: ADVANCED — OTP Detection, Safe Delete, Auto-Response
    // =========================================================================

    /**
     * Security audit scanner — scans all emails for OTP codes and sensitive keywords.
     *
     * Returns a list of String[5] entries:
     *   [0] type      — "otp" or "sensitive"
     *   [1] value     — the code digits or keyword
     *   [2] sender    — sender_name from the email
     *   [3] timestamp — formatted "MMM d, yyyy - hh:mm a"
     *   [4] ageStatus — "active" (< 15 min) | "expired" | "" (for sensitive)
     *
     * Sorted: sensitive findings first, then active OTPs, then expired OTPs.
     * Per unique (type, value, sender) tuple only the most recent email is kept.
     */
    /**
     * finding[] layout (9 elements):
     * [0] type        — "otp" | "sensitive"
     * [1] value       — code digits or keyword
     * [2] sender      — sender_name
     * [3] timestamp   — formatted display string
     * [4] ageStatus   — "active" | "expired" | "" (empty for sensitive)
     * [5] epochMs     — ms since epoch (for OTP countdown)
     * [6] emailId     — database email_id (for deep-link to inbox)
     * [7] findingKey  — composite dedup key (for mark-safe)
     * [8] isResolved  — "true" | "false"
     */
    public List<String[]> detectOTPs(int userId) {
        Map<String, String[]> findings = new LinkedHashMap<>();
        Set<String> resolvedKeys = getResolvedKeys(userId);

        Pattern otpPattern = Pattern.compile(
                "(?i)(?:otp|one.?time|verif(?:y|ication)|auth(?:entication|enticate)?|" +
                "security code|login code|access code|confirm(?:ation)? code|" +
                "2fa|mfa|two.?factor|passcode|pin|your code|enter.*?code|" +
                "\\bcode\\b|\\btoken\\b)[^\\d]{0,40}(\\b\\d{4,8}\\b)" +
                "|(\\b\\d{4,8}\\b)[^\\d]{0,40}(?:otp|one.?time|verif(?:y|ication)|" +
                "auth(?:entication|enticate)?|security code|login code|access code|" +
                "confirm(?:ation)? code|2fa|mfa|two.?factor|passcode|pin|" +
                "\\bcode\\b|\\btoken\\b)");
        Pattern keywordPattern = Pattern.compile("(?i)\\b(password|secret|credential|private.?key|access.?token)\\b");

        SimpleDateFormat fmt = new SimpleDateFormat("MMM d, yyyy - hh:mm a");
        long fifteenMinMs = 15L * 60 * 1000;
        long now = System.currentTimeMillis();

        // ORDER BY created_at DESC so the first occurrence of a duplicate key is the newest
        String sql = "SELECT email_id, sender_name, body, created_at FROM emails WHERE user_id = ? ORDER BY created_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                String body     = rs.getString("body");
                String sender   = rs.getString("sender_name");
                String emailId  = String.valueOf(rs.getInt("email_id"));
                if (body == null) continue;

                Timestamp createdAt = rs.getTimestamp("created_at");
                String tsDisplay = (createdAt != null) ? fmt.format(createdAt) : "Unknown";
                boolean active   = (createdAt != null) && (now - createdAt.getTime() < fifteenMinMs);
                String ageStatus = active ? "active" : "expired";
                String epochMs   = (createdAt != null) ? String.valueOf(createdAt.getTime()) : "0";

                Matcher otpMatcher = otpPattern.matcher(body);
                while (otpMatcher.find()) {
                    String code = otpMatcher.group(1) != null ? otpMatcher.group(1) : otpMatcher.group(2);
                    if (code != null && !isLikelyYear(code) && !isTrivalNumber(code)) {
                        String key = "otp|" + code + "|" + sender;
                        String resolved = resolvedKeys.contains(key) ? "true" : "false";
                        findings.putIfAbsent(key, new String[]{"otp", code, sender, tsDisplay, ageStatus, epochMs, emailId, key, resolved});
                    }
                }
                Matcher kwMatcher = keywordPattern.matcher(body);
                if (kwMatcher.find()) {
                    String keyword = kwMatcher.group();
                    String key = "sensitive|" + keyword.toLowerCase() + "|" + sender;
                    String resolved = resolvedKeys.contains(key) ? "true" : "false";
                    findings.putIfAbsent(key, new String[]{"sensitive", keyword, sender, tsDisplay, "", "0", emailId, key, resolved});
                }
            }
        } catch (SQLException e) { e.printStackTrace(); }

        // Sort: unresolved sensitive (0) → active OTP (1) → expired/resolved OTP (2) → resolved sensitive (3)
        List<String[]> sorted = new ArrayList<>(findings.values());
        sorted.sort((a, b) -> {
            boolean ra_resolved = "true".equals(a[8]);
            boolean rb_resolved = "true".equals(b[8]);
            int ra = ra_resolved ? 3 : ("sensitive".equals(a[0]) ? 0 : ("active".equals(a[4]) ? 1 : 2));
            int rb = rb_resolved ? 3 : ("sensitive".equals(b[0]) ? 0 : ("active".equals(b[4]) ? 1 : 2));
            return Integer.compare(ra, rb);
        });
        return sorted;
    }

    /** Creates the security_resolutions table if it does not already exist. */
    private void ensureResolutionsTable() {
        String sql = "CREATE TABLE IF NOT EXISTS security_resolutions (" +
                "resolution_id INT AUTO_INCREMENT PRIMARY KEY, " +
                "user_id INT NOT NULL, " +
                "finding_key VARCHAR(500) NOT NULL, " +
                "resolved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, " +
                "UNIQUE KEY unique_resolution (user_id, finding_key), " +
                "FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.executeUpdate();
        } catch (SQLException e) { /* table already exists — ignore */ }
    }

    /** Returns the set of finding keys the user has already resolved. */
    public Set<String> getResolvedKeys(int userId) {
        ensureResolutionsTable();
        Set<String> keys = new LinkedHashSet<>();
        String sql = "SELECT finding_key FROM security_resolutions WHERE user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) keys.add(rs.getString("finding_key"));
        } catch (SQLException e) { e.printStackTrace(); }
        return keys;
    }

    /** Inserts a resolved finding key for the user (idempotent). */
    public boolean markFindingResolved(int userId, String findingKey) {
        ensureResolutionsTable();
        String sql = "INSERT IGNORE INTO security_resolutions (user_id, finding_key) VALUES (?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, findingKey);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) { e.printStackTrace(); return false; }
    }

    /**
     * Deletes all otps rows whose display key matches "CODE (from SENDER)".
     * Called on dismiss so that a subsequent sync cannot re-surface the same entry.
     */
    public void deleteOtpByKey(int userId, String otpKey) {
        String sql = "DELETE FROM otps WHERE user_id = ? " +
                "AND CONCAT(otp_code, ' (from ', sender_name, ')') = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, otpKey);
            ps.executeUpdate();
        } catch (SQLException e) { e.printStackTrace(); }
    }

    /**
     * Returns ONLY one unique OTP per sender from the otps table
     * within a 15-minute freshness window.
     */
    public List<String> getFreshOTPs(int userId) {
        List<String> freshOTPs = new ArrayList<>();
        String sql = "SELECT sender_name, otp_code FROM otps " +
                "WHERE user_id = ? AND timestamp > NOW() - INTERVAL 15 MINUTE " +
                "GROUP BY sender_name, otp_code";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                freshOTPs.add(rs.getString("otp_code") + " (from " + rs.getString("sender_name") + ")");
            }
        } catch (SQLException e) { e.printStackTrace(); }
        return freshOTPs;
    }

    /** Soft-delete an email by recording it in deleted_emails. */
    public void safeDelete(int emailId) {
        String sql = "INSERT INTO deleted_emails (email_id) VALUES (?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, emailId);
            ps.executeUpdate();
        } catch (SQLException e) { e.printStackTrace(); }
    }

    /** Get all soft-deleted emails for a user. */
    public List<Email> getDeletedEmails(int userId) {
        List<Email> list = new ArrayList<>();
        String sql = "SELECT e.* FROM emails e " +
                "JOIN deleted_emails d ON e.email_id = d.email_id " +
                "WHERE e.user_id = ? ORDER BY d.deleted_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                list.add(new Email(rs.getInt("email_id"), rs.getString("sender_name"),
                        rs.getString("subject"), rs.getString("body"),
                        rs.getString("category"), rs.getString("created_at"), null));
            }
        } catch (SQLException e) { e.printStackTrace(); }
        return list;
    }

    /** Restore a soft-deleted email. */
    public void restoreEmail(int emailId) {
        String sql = "DELETE FROM deleted_emails WHERE email_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, emailId);
            ps.executeUpdate();
        } catch (SQLException e) { e.printStackTrace(); }
    }

    // =========================================================================
    // SECTION 5: GMAIL SYNC — De-duplicated via UNIQUE message_id
    // =========================================================================

    /**
     * Syncs the latest 5 Gmail messages via IMAP.
     * Uses INSERT IGNORE so the UNIQUE constraint on message_id
     * silently rejects any duplicates.
     *
     * @return number of messages processed (>=0), or -1 on connection failure.
     */
    public int syncGmail(int userId, String email, String appPassword) {
        System.out.println("🔄 [SYNC] Starting Gmail sync for user_id=" + userId + ", email=" + email);

        // Clean up orphaned deleted_emails from any prior TRUNCATE
        cleanOrphanedDeletes();

        Properties props = new Properties();
        props.put("mail.imaps.host", "imap.gmail.com");
        props.put("mail.imaps.port", "993");
        props.put("mail.imaps.ssl.enable", "true");
        props.put("mail.imaps.auth", "true");
        props.put("mail.imaps.connectiontimeout", "10000");
        props.put("mail.imaps.timeout", "10000");

        Store store = null;
        Folder inbox = null;

        try {
            Session session = Session.getInstance(props);
            store = session.getStore("imaps");

            System.out.println("🔄 [SYNC] Connecting to imap.gmail.com...");
            store.connect("imap.gmail.com", email, appPassword);
            System.out.println("🔄 [SYNC] Connected to Gmail Store: " + store.isConnected());

            inbox = store.getFolder("INBOX");
            inbox.open(Folder.READ_ONLY);

            Message[] messages = inbox.getMessages();
            System.out.println("🔄 [SYNC] Total messages in Gmail INBOX: " + messages.length);

            int count = Math.min(20, messages.length);
            if (count == 0) {
                System.out.println("🔄 [SYNC] No messages found in inbox. Nothing to sync.");
                return 0;
            }

            // Batch-prefetch FLAGS + ENVELOPE in a single IMAP round-trip
            FetchProfile fp = new FetchProfile();
            fp.add(FetchProfile.Item.FLAGS);
            fp.add(FetchProfile.Item.ENVELOPE);
            inbox.fetch(messages, fp);

            int saved = 0;
            int restored = 0;
            for (int i = messages.length - 1; i >= messages.length - count; i--) {
                try {
                    String sender = messages[i].getFrom() != null && messages[i].getFrom().length > 0
                            ? messages[i].getFrom()[0].toString()
                            : "Unknown Sender";
                    String subject = messages[i].getSubject() != null
                            ? messages[i].getSubject()
                            : "(No Subject)";
                    String body;
                    try {
                        body = extractTextContent(messages[i]);
                    } catch (Exception bodyEx) {
                        System.out.println("⚠️ [SYNC] Could not extract body for message " + i + ", using fallback. Error: " + bodyEx.getMessage());
                        body = "[Could not extract email body]";
                    }

                    // Extract the RFC-822 Message-ID for dedup
                    String[] msgIdHeader = messages[i].getHeader("Message-ID");
                    String messageId = (msgIdHeader != null && msgIdHeader.length > 0)
                            ? msgIdHeader[0]
                            : (sender + "|" + subject + "|" + messages[i].getSentDate());

                    System.out.println("🔄 [SYNC] Processing msg " + (messages.length - i) + "/" + count
                            + " | From: " + sender + " | Subject: " + subject + " | MsgID: " + messageId);

                    // Read the Gmail \Seen flag — already prefetched, no extra IMAP round-trip
                    boolean isSeen = false;
                    try {
                        isSeen = messages[i].isSet(Flags.Flag.SEEN);
                    } catch (Exception flagEx) {
                        // Leave isSeen = false — safe default
                    }

                    // Preserve original sent date instead of using NOW()
                    java.util.Date sentDate = messages[i].getSentDate();
                    Timestamp originalDate = (sentDate != null)
                            ? new Timestamp(sentDate.getTime())
                            : new Timestamp(System.currentTimeMillis());

                    boolean wasInserted = saveToDatabase(userId, sender, subject, body, messageId, originalDate, isSeen);
                    if (wasInserted) {
                        saved++;
                    } else {
                        restored++;  // existing email was restored from deleted_emails (if applicable)
                    }

                } catch (Exception msgEx) {
                    System.out.println("❌ [SYNC] Failed to process message index " + i + ": " + msgEx.getMessage());
                    msgEx.printStackTrace();
                    // Continue to next message — don't let one bad message kill the whole sync
                }
            }

            System.out.println("✅ [SYNC] Done. " + saved + " new, " + restored + " existing — " + count + " processed.");
            return saved + restored;

        } catch (AuthenticationFailedException authEx) {
            System.out.println("❌ [SYNC] AUTHENTICATION FAILED — Bad email/app-password!");
            System.out.println("❌ [SYNC] Email used: " + email);
            System.out.println("❌ [SYNC] Ensure you are using a 16-character App Password, NOT your Gmail password.");
            authEx.printStackTrace();
            return -1;
        } catch (Exception e) {
            System.out.println("❌ [SYNC] FATAL ERROR during Gmail sync: " + e.getClass().getSimpleName() + " — " + e.getMessage());
            e.printStackTrace();
            return -1;
        } finally {
            // Always close resources
            try { if (inbox != null && inbox.isOpen()) inbox.close(false); } catch (Exception ignored) {}
            try { if (store != null && store.isConnected()) store.close(); } catch (Exception ignored) {}
        }
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    /**
     * Inserts a synced email using INSERT IGNORE.
     * The UNIQUE constraint on message_id silently skips duplicates.
     * Also restores any soft-deleted email with the same message_id.
     *
     * @return true if a new row was actually inserted, false if duplicate/skipped.
     */
    private boolean saveToDatabase(int userId, String sender, String subject, String body, String messageId, Timestamp sentDate, boolean isSeen) {
        int bucketId = resolveBucketId(userId, sender, subject);
        List<String[]> rules = getFeedbackRules(userId);
        String category = GeminiCategorizationService.categorize(userId, sender, subject, body, rules);

        // ON DUPLICATE KEY UPDATE keeps is_read in sync with Gmail on every re-sync
        // without overwriting any other locally-managed column (category, body, etc.)
        String sql = "INSERT INTO emails " +
                "(user_id, sender_name, subject, body, category, bucket_id, message_id, created_at, is_read) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) " +
                "ON DUPLICATE KEY UPDATE is_read = VALUES(is_read)";

        boolean inserted = false;
        int emailId = -1;
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, userId);
            ps.setString(2, sender);
            ps.setString(3, subject);
            ps.setString(4, body);
            ps.setString(5, category);
            if (bucketId > 0) ps.setInt(6, bucketId); else ps.setNull(6, Types.INTEGER);
            ps.setString(7, messageId);
            ps.setTimestamp(8, sentDate);
            ps.setBoolean(9, isSeen);
            int rows = ps.executeUpdate();
            // rows==1: new insert; rows==2: duplicate updated; rows==0: duplicate unchanged
            inserted = rows == 1;

            // Get the generated email_id if this was a new insert
            if (inserted) {
                ResultSet rs = ps.getGeneratedKeys();
                if (rs.next()) {
                    emailId = rs.getInt(1);
                }
            }

            System.out.println("   💾 [DB] INSERT result: " + (inserted ? "SAVED ✅" : "SKIPPED (duplicate) ⏭️") + " | message_id=" + messageId);
        } catch (SQLException e) {
            System.out.println("   ❌ [DB] SQL ERROR saving email: " + e.getMessage());
            e.printStackTrace();
        }

        // If the email already existed (duplicate), restore it from deleted_emails
        // so it reappears in the inbox after an explicit sync
        if (!inserted) {
            restoreByMessageId(userId, messageId);
        }

        // Only process OTP extraction and auto-reply for genuinely new emails.
        // Calling extractAndStoreOTP on duplicates would re-stamp old OTPs with NOW(),
        // making day-old codes appear as fresh security alerts on every sync.
        if (inserted && emailId > 0) {
            extractAndStoreOTP(userId, sender, body);
            processAutoReply(userId, emailId, sender, sender, subject, body);
        }

        return inserted;
    }

    /**
     * Restores a soft-deleted email by removing its deleted_emails entry,
     * looked up via message_id so it becomes visible again after re-sync.
     */
    private void restoreByMessageId(int userId, String messageId) {
        String sql = "DELETE d FROM deleted_emails d " +
                "JOIN emails e ON d.email_id = e.email_id " +
                "WHERE e.user_id = ? AND e.message_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, messageId);
            int restored = ps.executeUpdate();
            if (restored > 0) {
                System.out.println("   ♻️ [DB] Restored previously deleted email | message_id=" + messageId);
            }
        } catch (SQLException e) { e.printStackTrace(); }
    }

    /**
     * Shared bucket-rule resolver. Checks sender and keyword rules
     * from global default buckets AND this user's custom buckets.
     * Returns the matching bucket_id, or 0 if no rule matches.
     */
    private int resolveBucketId(int userId, String sender, String subject) {
        String ruleSql = "SELECT r.bucket_id FROM bucket_rules r " +
                "JOIN buckets b ON r.bucket_id = b.bucket_id " +
                "WHERE (b.user_id IS NULL OR b.user_id = ?) " +
                "AND ((r.rule_type = 'sender' AND LOWER(TRIM(?)) LIKE CONCAT('%', LOWER(TRIM(r.rule_value)), '%')) " +
                "  OR (r.rule_type = 'keyword' AND LOWER(?) LIKE CONCAT('%', LOWER(TRIM(r.rule_value)), '%'))) " +
                "LIMIT 1";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(ruleSql)) {
            ps.setInt(1, userId);
            ps.setString(2, sender != null ? sender : "");
            ps.setString(3, subject != null ? subject : "");
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getInt("bucket_id");
        } catch (SQLException e) { e.printStackTrace(); }
        return 0;
    }

    /**
     * Scans the email body for a 4-6 digit OTP code and stores it
     * in the otps table for the security alert bar.
     * Only detects codes that appear near OTP-related keywords.
     * Explicitly rejects years (2020-2039) and common non-OTP numbers.
     */
    private void extractAndStoreOTP(int userId, String sender, String body) {
        if (body == null) return;
        // Only match digits near strong OTP keywords (NOT generic "code")
        Pattern keywordPattern = Pattern.compile(
                "(?i)(?:otp|verification code|verify code|pin|passcode|one.?time|security code|login code)[^\\d]{0,30}(\\b\\d{4,6}\\b)" +
                "|" +
                "(\\b\\d{4,6}\\b)[^\\d]{0,30}(?:otp|verification code|verify code|pin|passcode|one.?time|security code|login code)");
        Matcher matcher = keywordPattern.matcher(body);
        if (matcher.find()) {
            String code = matcher.group(1) != null ? matcher.group(1) : matcher.group(2);
            // Reject years (2020-2039) and trivially simple numbers
            if (isLikelyYear(code) || isTrivalNumber(code)) {
                System.out.println("   ⏭️ [OTP] Rejected false positive: " + code + " (looks like a year/trivial number)");
                return;
            }
            String sql = "INSERT INTO otps (user_id, sender_name, otp_code, timestamp) VALUES (?, ?, ?, NOW())";
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, userId);
                ps.setString(2, sender);
                ps.setString(3, code);
                ps.executeUpdate();
                System.out.println("   🔐 [OTP] Stored: " + code + " from " + sender);
            } catch (SQLException e) { e.printStackTrace(); }
        }
    }

    /** Returns true if the number looks like a calendar year (2020-2039). */
    private boolean isLikelyYear(String code) {
        if (code == null || code.length() != 4) return false;
        try {
            int num = Integer.parseInt(code);
            return num >= 2020 && num <= 2039;
        } catch (NumberFormatException e) { return false; }
    }

    /** Returns true if the number is trivially simple (e.g., 0000, 1234, 1111). */
    private boolean isTrivalNumber(String code) {
        if (code == null) return false;
        // All same digits: 0000, 1111, etc.
        if (code.chars().distinct().count() == 1) return true;
        // Sequential: 1234, 123456
        boolean seq = true;
        for (int i = 1; i < code.length(); i++) {
            if (code.charAt(i) - code.charAt(i - 1) != 1) { seq = false; break; }
        }
        return seq;
    }

    // =========================================================================
    // SECTION 6: SENT REPLIES — Save, List, Conversations
    // =========================================================================

    /** Save a sent reply to the database for conversation history. */
    public void saveReply(int userId, String recipientEmail, String recipientName, String subject, String message) {
        // Auto-create the table if it doesn't exist
        ensureRepliesTable();
        String sql = "INSERT INTO sent_replies (user_id, recipient_email, recipient_name, subject, message) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, recipientEmail);
            ps.setString(3, recipientName);
            ps.setString(4, subject);
            ps.setString(5, message);
            ps.executeUpdate();
            System.out.println("💾 [REPLY-DB] Saved reply to " + recipientEmail);
        } catch (SQLException e) {
            System.out.println("[REPLY-DB] ERROR saving reply: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /** Get all unique recipients the user has replied to, with latest reply info. */
    public List<String[]> getReplyThreads(int userId) {
        ensureRepliesTable();
        List<String[]> threads = new ArrayList<>();
        String sql = "SELECT recipient_email, recipient_name, subject, message, sent_at, " +
                "(SELECT COUNT(*) FROM sent_replies r2 WHERE r2.user_id = r1.user_id AND r2.recipient_email = r1.recipient_email) AS msg_count " +
                "FROM sent_replies r1 WHERE user_id = ? AND reply_id IN " +
                "(SELECT MAX(reply_id) FROM sent_replies WHERE user_id = ? GROUP BY recipient_email) " +
                "ORDER BY sent_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setInt(2, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                threads.add(new String[]{
                    rs.getString("recipient_email"),
                    rs.getString("recipient_name"),
                    rs.getString("subject"),
                    rs.getString("message"),
                    rs.getString("sent_at"),
                    String.valueOf(rs.getInt("msg_count"))
                });
            }
        } catch (SQLException e) { e.printStackTrace(); }
        return threads;
    }

    /**
     * Get the full conversation thread between the user and a specific recipient.
     * Combines received emails + sent replies, ordered chronologically.
     * Each entry: [type, timestamp, subject, body, sender_display]
     *   type = "received" or "sent"
     */
    public List<String[]> getConversation(int userId, String recipientEmail) {
        ensureRepliesTable();
        List<String[]> conversation = new ArrayList<>();

        // 1. Get received emails from this sender
        String incomingSql = "SELECT 'received' AS type, created_at AS ts, subject, body, sender_name " +
                "FROM emails WHERE user_id = ? AND (sender_name LIKE ? OR sender_name LIKE ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(incomingSql)) {
            ps.setInt(1, userId);
            ps.setString(2, "%" + recipientEmail + "%");
            // Also match by the part before @ (e.g., "john" from "john@gmail.com")
            String namePart = recipientEmail.contains("@") ? recipientEmail.substring(0, recipientEmail.indexOf("@")) : recipientEmail;
            ps.setString(3, "%" + namePart + "%");
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                conversation.add(new String[]{
                    rs.getString("type"),
                    rs.getString("ts"),
                    rs.getString("subject"),
                    rs.getString("body"),
                    rs.getString("sender_name")
                });
            }
        } catch (SQLException e) { e.printStackTrace(); }

        // 2. Get sent replies to this recipient
        String sentSql = "SELECT 'sent' AS type, sent_at AS ts, subject, message AS body, 'You' AS sender_name " +
                "FROM sent_replies WHERE user_id = ? AND recipient_email = ? ORDER BY sent_at";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sentSql)) {
            ps.setInt(1, userId);
            ps.setString(2, recipientEmail);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                conversation.add(new String[]{
                    rs.getString("type"),
                    rs.getString("ts"),
                    rs.getString("subject"),
                    rs.getString("body"),
                    rs.getString("sender_name")
                });
            }
        } catch (SQLException e) { e.printStackTrace(); }

        // 3. Sort by timestamp
        conversation.sort((a, b) -> {
            if (a[1] == null) return -1;
            if (b[1] == null) return 1;
            return a[1].compareTo(b[1]);
        });

        return conversation;
    }

    /** Auto-create the sent_replies table if it doesn't exist. */
    private void ensureRepliesTable() {
        String sql = "CREATE TABLE IF NOT EXISTS sent_replies (" +
                "reply_id INT AUTO_INCREMENT PRIMARY KEY, " +
                "user_id INT NOT NULL, " +
                "recipient_email VARCHAR(255) NOT NULL, " +
                "recipient_name VARCHAR(255), " +
                "subject VARCHAR(500), " +
                "message TEXT NOT NULL, " +
                "sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, " +
                "FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.executeUpdate();
        } catch (SQLException e) { /* table already exists — ignore */ }
    }

    // =========================================================================
    // SECTION 8: AI FEEDBACK RULES — Human-in-the-Loop Learning
    // =========================================================================

    /** Creates the ai_feedback_rules table if it does not already exist. */
    private void ensureFeedbackTable() {
        String sql = "CREATE TABLE IF NOT EXISTS ai_feedback_rules (" +
                "rule_id INT AUTO_INCREMENT PRIMARY KEY, " +
                "user_id INT NOT NULL, " +
                "sender_pattern VARCHAR(255) NOT NULL, " +
                "preferred_priority VARCHAR(50) NOT NULL, " +
                "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, " +
                "UNIQUE KEY unique_user_sender (user_id, sender_pattern), " +
                "FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.executeUpdate();
        } catch (SQLException e) { /* table already exists — ignore */ }
    }

    /** Returns all feedback rules for a user as [senderPattern, preferredPriority] pairs. */
    public List<String[]> getFeedbackRules(int userId) {
        ensureFeedbackTable();
        List<String[]> rules = new ArrayList<>();
        String sql = "SELECT sender_pattern, preferred_priority FROM ai_feedback_rules WHERE user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                rules.add(new String[]{ rs.getString("sender_pattern"), rs.getString("preferred_priority") });
            }
        } catch (SQLException e) { e.printStackTrace(); }
        return rules;
    }

    /** Updates the category of a specific email owned by the given user. */
    public boolean updateEmailCategory(int emailId, int userId, String category) {
        String sql = "UPDATE emails SET category = ? WHERE email_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, category);
            ps.setInt(2, emailId);
            ps.setInt(3, userId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) { e.printStackTrace(); return false; }
    }

    /** Upserts a sender → priority preference into ai_feedback_rules. */
    public boolean saveFeedbackRule(int userId, String senderPattern, String priority) {
        ensureFeedbackTable();
        String sql = "INSERT INTO ai_feedback_rules (user_id, sender_pattern, preferred_priority) " +
                "VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE preferred_priority = VALUES(preferred_priority)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, senderPattern);
            ps.setString(3, priority);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) { e.printStackTrace(); return false; }
    }

    /** Returns the sender_name of an email, scoped to the given user. */
    public String getSenderByEmailId(int emailId, int userId) {
        String sql = "SELECT sender_name FROM emails WHERE email_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, emailId);
            ps.setInt(2, userId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getString("sender_name");
        } catch (SQLException e) { e.printStackTrace(); }
        return null;
    }

    /**
     * Smart email categorization based on sender, subject, and body content.
     *
     * needs_decision  — requires user action (OTPs, approvals, deadlines, payments)
     * needs_attention  — important but informational (personal mail, receipts, updates)
     * ignored_safely   — safe to skip (newsletters, promos, automated marketing)
     */
    private String categorizeEmail(String sender, String subject, String body) {
        String senderLower = (sender != null) ? sender.toLowerCase() : "";
        String subjectLower = (subject != null) ? subject.toLowerCase() : "";
        String bodySnippet = (body != null) ? body.toLowerCase().substring(0, Math.min(body.length(), 1500)) : "";
        String combined = subjectLower + " " + bodySnippet;

        // ── TIER 1: NEEDS DECISION — requires immediate user action ──
        String[] decisionKeywords = {
            "urgent", "action required", "action needed", "deadline", "approve",
            "confirm your", "verify your", "review required", "respond by",
            "reply needed", "payment due", "invoice", "due date", "expiring soon",
            "renew your", "immediate attention", "asap", "complete your registration",
            "submit your", "sign required", "reset your password", "verify your account",
            "otp", "verification code", "security code", "login code", "passcode",
            "one-time", "one time password", "two-factor", "2fa", "mfa code",
            "suspicious activity", "unauthorized", "account locked", "security alert",
            "failed login", "password changed", "confirm this transaction"
        };
        for (String kw : decisionKeywords) {
            if (subjectLower.contains(kw) || combined.contains(kw)) {
                return "needs_decision";
            }
        }

        // ── TIER 3: IGNORED SAFELY — newsletters, marketing, promotions ──
        // Check this BEFORE needs_attention so promos don't get elevated
        String[] ignoreKeywords = {
            "unsubscribe", "opt out", "opt-out", "manage preferences",
            "email preferences", "no longer wish to receive",
            "weekly digest", "daily digest", "monthly newsletter",
            "% off", "limited time", "special offer", "exclusive deal",
            "shop now", "buy now", "order now", "free shipping",
            "advertisement", "sponsored", "you may also like"
        };
        for (String kw : ignoreKeywords) {
            if (combined.contains(kw)) return "ignored_safely";
        }

        // Sender-based promo detection
        String[] promoSenders = {
            "newsletter@", "news@", "marketing@", "promotions@",
            "offers@", "deals@", "promo@", "campaign@", "bulk@",
            "mailchimp", "sendgrid", "constantcontact"
        };
        for (String s : promoSenders) {
            if (senderLower.contains(s)) return "ignored_safely";
        }

        // ── TIER 2: NEEDS ATTENTION — everything else that's meaningful ──
        // Personal mail, receipts, order confirmations, real notifications
        return "needs_attention";
    }

    /**
     * Re-categorizes ALL existing emails for a user using the smart logic.
     * Call this once to fix legacy "ignored_safely" data.
     */
    public int recategorizeAllEmails(int userId) {
        int updated = 0;
        String selectSql = "SELECT email_id, sender_name, subject, body FROM emails WHERE user_id = ?";
        String updateSql = "UPDATE emails SET category = ? WHERE email_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement sel = conn.prepareStatement(selectSql);
             PreparedStatement upd = conn.prepareStatement(updateSql)) {
            sel.setInt(1, userId);
            ResultSet rs = sel.executeQuery();
            while (rs.next()) {
                int emailId = rs.getInt("email_id");
                String sender = rs.getString("sender_name");
                String subject = rs.getString("subject");
                String body = rs.getString("body");
                String newCat = categorizeEmail(sender, subject, body);
                upd.setString(1, newCat);
                upd.setInt(2, emailId);
                upd.addBatch();
                updated++;
            }
            upd.executeBatch();
            System.out.println("🔄 [RECAT] Re-categorized " + updated + " emails for user_id=" + userId);
        } catch (SQLException e) {
            System.out.println("[RECAT] ERROR: " + e.getMessage());
            e.printStackTrace();
        }
        return updated;
    }

    /**
     * Extracts plain-text content from a Jakarta Mail Message,
     * handling both simple text and multipart MIME messages.
     */
    private String extractTextContent(Message message) throws Exception {
        Object content = message.getContent();
        if (content instanceof String) {
            return (String) content;
        }
        if (content instanceof Multipart mp) {
            for (int i = 0; i < mp.getCount(); i++) {
                BodyPart bp = mp.getBodyPart(i);
                if (bp.isMimeType("text/plain")) {
                    return bp.getContent().toString();
                }
            }
            for (int i = 0; i < mp.getCount(); i++) {
                BodyPart bp = mp.getBodyPart(i);
                if (bp.getContentType().toLowerCase().startsWith("text/")) {
                    return bp.getContent().toString();
                }
            }
        }
        return content != null ? content.toString() : "";
    }

    // =========================================================================
    // SECTION 7: AUTO-REPLY RULES
    // =========================================================================

    /**
     * Get all auto-reply rules for a user.
     * @return List of [rule_id, keyword, reply_message, is_active]
     */
    public List<String[]> getAutoReplyRules(int userId) {
        List<String[]> rules = new ArrayList<>();
        String sql = "SELECT rule_id, keyword, reply_message, is_active FROM auto_reply_rules WHERE user_id = ? ORDER BY created_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                rules.add(new String[]{
                    String.valueOf(rs.getInt("rule_id")),
                    rs.getString("keyword"),
                    rs.getString("reply_message"),
                    String.valueOf(rs.getBoolean("is_active"))
                });
            }
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error fetching rules: " + e.getMessage());
            e.printStackTrace();
        }
        return rules;
    }

    /**
     * Add a new auto-reply rule for a user.
     */
    public boolean addAutoReplyRule(int userId, String keyword, String replyMessage) {
        String sql = "INSERT INTO auto_reply_rules (user_id, keyword, reply_message, is_active) VALUES (?, ?, ?, TRUE)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, keyword.toLowerCase().trim());
            ps.setString(3, replyMessage.trim());
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error adding rule: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Delete an auto-reply rule.
     */
    public boolean deleteAutoReplyRule(int ruleId, int userId) {
        String sql = "DELETE FROM auto_reply_rules WHERE rule_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ruleId);
            ps.setInt(2, userId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error deleting rule: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Toggle a rule's active status.
     */
    public boolean toggleAutoReplyRule(int ruleId, int userId) {
        String sql = "UPDATE auto_reply_rules SET is_active = NOT is_active WHERE rule_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ruleId);
            ps.setInt(2, userId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error toggling rule: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Process an incoming email and check if it matches any auto-reply rules.
     * If matched AND sender is NOT a no-reply address, create a draft reply.
     * @return true if a draft was created, false otherwise.
     */
    public boolean processAutoReply(int userId, int emailId, String senderEmail, String senderName, String subject, String body) {
        // 1. Security check: ignore no-reply senders
        if (isNoReplySender(senderEmail)) {
            System.out.println("[AUTO-REPLY] Ignoring no-reply sender: " + senderEmail);
            return false;
        }

        // 2. Get all active rules for this user
        String ruleSql = "SELECT rule_id, keyword, reply_message FROM auto_reply_rules WHERE user_id = ? AND is_active = TRUE";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(ruleSql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();

            String bodyLower = (body != null) ? body.toLowerCase() : "";
            String subjectLower = (subject != null) ? subject.toLowerCase() : "";
            String combined = subjectLower + " " + bodyLower;

            while (rs.next()) {
                int ruleId = rs.getInt("rule_id");
                String keyword = rs.getString("keyword").toLowerCase();
                String replyMessage = rs.getString("reply_message");

                // Check if keyword exists in subject or body
                if (combined.contains(keyword)) {
                    System.out.println("[AUTO-REPLY] ✅ Match found! Keyword: '" + keyword + "' in email from " + senderEmail);
                    // Create draft reply
                    return createDraftReply(userId, emailId, ruleId, senderEmail, senderName, subject, replyMessage, conn);
                }
            }
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error processing auto-reply: " + e.getMessage());
            e.printStackTrace();
        }
        return false;
    }

    /**
     * Create a draft reply (not sent, just stored for user review).
     */
    private boolean createDraftReply(int userId, int emailId, int ruleId, String recipientEmail,
                                     String recipientName, String originalSubject, String draftMessage, Connection conn) {
        String sql = "INSERT IGNORE INTO auto_drafted_replies (user_id, email_id, rule_id, recipient_email, recipient_name, subject, draft_message) " +
                     "VALUES (?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setInt(2, emailId);
            ps.setInt(3, ruleId);
            ps.setString(4, recipientEmail);
            ps.setString(5, recipientName);
            ps.setString(6, "Re: " + originalSubject);
            ps.setString(7, draftMessage);
            int rows = ps.executeUpdate();
            if (rows > 0) {
                System.out.println("[AUTO-REPLY] 📝 Draft created for email_id=" + emailId);
                return true;
            } else {
                System.out.println("[AUTO-REPLY] ⏭️ Draft already exists for email_id=" + emailId + " with rule_id=" + ruleId);
                return false;
            }
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error creating draft: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Get all auto-drafted replies for a user.
     * @return List of [draft_id, email_id, recipient_email, recipient_name, subject, draft_message, created_at]
     */
    public List<String[]> getAutoDraftedReplies(int userId) {
        List<String[]> drafts = new ArrayList<>();
        String sql = "SELECT draft_id, email_id, recipient_email, recipient_name, subject, draft_message, created_at " +
                     "FROM auto_drafted_replies WHERE user_id = ? ORDER BY created_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                drafts.add(new String[]{
                    String.valueOf(rs.getInt("draft_id")),
                    String.valueOf(rs.getInt("email_id")),
                    rs.getString("recipient_email"),
                    rs.getString("recipient_name"),
                    rs.getString("subject"),
                    rs.getString("draft_message"),
                    rs.getString("created_at")
                });
            }
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error fetching drafts: " + e.getMessage());
            e.printStackTrace();
        }
        return drafts;
    }

    /**
     * Delete a drafted reply.
     */
    public boolean deleteDraftReply(int draftId, int userId) {
        String sql = "DELETE FROM auto_drafted_replies WHERE draft_id = ? AND user_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, draftId);
            ps.setInt(2, userId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.out.println("[AUTO-REPLY] Error deleting draft: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Check if an email sender is a no-reply address.
     * Security: automatically ignore no-reply senders.
     */
    private boolean isNoReplySender(String sender) {
        if (sender == null) return true;
        String lower = sender.toLowerCase();
        return lower.contains("noreply") || lower.contains("no-reply") || lower.contains("no_reply")
            || lower.contains("donotreply") || lower.contains("do-not-reply") || lower.contains("do_not_reply")
            || lower.contains("mailer-daemon") || !lower.contains("@");
    }
}
