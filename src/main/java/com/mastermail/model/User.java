package com.mastermail.model;

public class User {
    private int id;
    private String name;
    private String email;
    private String role;        // "USER" or "ADMIN"
    private String lastLogin;   // Timestamp string from DB
    private String gmailEmail;        // User's linked Gmail for IMAP sync
    private String gmailAppPassword;  // 16-char Google App Password

    /** Backward-compatible constructor (existing servlets still use this). */
    public User(int id, String name, String email) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.role = "USER";
    }

    /** Full constructor for admin dashboard. */
    public User(int id, String name, String email, String role, String lastLogin) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.role = (role != null) ? role : "USER";
        this.lastLogin = lastLogin;
    }

    // Getters
    public int getId() { return id; }
    public String getName() { return name; }
    public String getEmail() { return email; }
    public String getRole() { return role != null ? role : "USER"; }
    public String getLastLogin() { return lastLogin; }
    public String getGmailEmail() { return gmailEmail; }
    public String getGmailAppPassword() { return gmailAppPassword; }

    // Setters
    public void setRole(String role) { this.role = role; }
    public void setLastLogin(String lastLogin) { this.lastLogin = lastLogin; }
    public void setGmailEmail(String gmailEmail) { this.gmailEmail = gmailEmail; }
    public void setGmailAppPassword(String gmailAppPassword) { this.gmailAppPassword = gmailAppPassword; }

    /** Convenience check for JSP/filter use. */
    public boolean isAdmin() { return "ADMIN".equalsIgnoreCase(role); }

    /** True if user has linked their Gmail for syncing. */
    public boolean hasGmailLinked() {
        return gmailEmail != null && !gmailEmail.isBlank()
                && gmailAppPassword != null && !gmailAppPassword.isBlank();
    }
}