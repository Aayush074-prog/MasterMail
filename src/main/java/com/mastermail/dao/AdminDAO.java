package com.mastermail.dao;

import com.mastermail.model.User;
import com.mastermail.util.DBConnection;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Data-access layer for the Admin Command Center.
 *
 * PREREQUISITE SQL (run once in the MySQL console):
 * -----------------------------------------------
 *   ALTER TABLE users ADD COLUMN role       VARCHAR(10)  NOT NULL DEFAULT 'USER';
 *   ALTER TABLE users ADD COLUMN last_login TIMESTAMP    NULL;
 *   UPDATE users SET role = 'ADMIN' WHERE email = 'aayush.das@mitwpu.edu.in';
 * -----------------------------------------------
 */
public class AdminDAO {

    // =========================================================================
    //  STATISTICS
    // =========================================================================

    /** Returns total registered users. */
    public int getTotalUsersCount() {
        String sql = "SELECT COUNT(*) FROM users";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getInt(1);
        } catch (SQLException e) { e.printStackTrace(); }
        return 0;
    }

    /** Returns users whose last_login is within the last 24 hours. */
    public int getActiveUsersCount() {
        String sql = "SELECT COUNT(*) FROM users WHERE last_login > NOW() - INTERVAL 24 HOUR";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getInt(1);
        } catch (SQLException e) {
            // last_login column might not exist yet — return 0
            System.out.println("[ADMIN] getActiveUsersCount failed (column may not exist): " + e.getMessage());
        }
        return 0;
    }

    /** Total emails stored across all accounts. */
    public int getTotalEmailsCount() {
        String sql = "SELECT COUNT(*) FROM emails";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getInt(1);
        } catch (SQLException e) { e.printStackTrace(); }
        return 0;
    }

    // =========================================================================
    //  USER MANAGEMENT
    // =========================================================================

    /** Returns every user for the admin table. */
    public List<User> getAllUsers() {
        List<User> list = new ArrayList<>();
        String sql = "SELECT user_id, name, email, role, last_login FROM users ORDER BY user_id";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                list.add(new User(
                        rs.getInt("user_id"),
                        rs.getString("name"),
                        rs.getString("email"),
                        rs.getString("role"),
                        rs.getString("last_login")
                ));
            }
        } catch (SQLException e) {
            // If role/last_login columns don't exist yet, fall back to basic query
            System.out.println("[ADMIN] Full query failed, trying fallback: " + e.getMessage());
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement("SELECT user_id, name, email FROM users ORDER BY user_id")) {
                ResultSet rs = ps.executeQuery();
                while (rs.next()) {
                    list.add(new User(rs.getInt("user_id"), rs.getString("name"), rs.getString("email")));
                }
            } catch (SQLException ex) { ex.printStackTrace(); }
        }
        return list;
    }

    /**
     * Cascading delete: removes all OTPs → deleted_emails → emails → bucket_rules →
     * buckets → and finally the user row itself.
     */
    public boolean deleteUser(int userId) {
        String[] cascadeSql = {
                "DELETE FROM otps WHERE user_id = ?",
                "DELETE d FROM deleted_emails d JOIN emails e ON d.email_id = e.email_id WHERE e.user_id = ?",
                "DELETE FROM emails WHERE user_id = ?",
                "DELETE r FROM bucket_rules r JOIN buckets b ON r.bucket_id = b.bucket_id WHERE b.user_id = ?",
                "DELETE FROM buckets WHERE user_id = ?",
                "DELETE FROM users WHERE user_id = ?"
        };
        try (Connection conn = DBConnection.getConnection()) {
            conn.setAutoCommit(false);
            try {
                for (String sql : cascadeSql) {
                    try (PreparedStatement ps = conn.prepareStatement(sql)) {
                        ps.setInt(1, userId);
                        ps.executeUpdate();
                    }
                }
                conn.commit();
                System.out.println("🗑️ [ADMIN] Cascading delete complete for user_id=" + userId);
                return true;
            } catch (SQLException e) {
                conn.rollback();
                System.out.println("❌ [ADMIN] Cascading delete FAILED for user_id=" + userId);
                e.printStackTrace();
                return false;
            } finally {
                conn.setAutoCommit(true);
            }
        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        }
    }
}

