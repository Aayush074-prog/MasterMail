<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.mastermail.model.*, java.util.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
                .replace("\"","&quot;").replace("'","&#39;");
    }
%>
<html>
<head>
    <title>MasterMail — Admin Command Center</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">

    <style>
        :root {
            --glass: rgba(255, 255, 255, 0.05);
            --primary: #6f42c1;
            --primary-hover: #8559da;
            --bg: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.55);
            --text-muted: #94a3b8;

            --glow-security: #ff4757;
            --glow-personal: #3498db;
            --glow-work: #2ecc71;
            --glow-promotions: #f39c12;
            --glow-admin: #e056fd;
            --glow-default: #95a5a6;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            background: var(--bg);
            color: white;
            font-family: 'Inter', sans-serif;
            margin: 0;
            display: flex;
            height: 100vh;
            overflow: hidden;
        }

        /* ===== SIDEBAR ===== */
        .sidebar {
            width: 260px;
            background: #1e293b;
            padding: 30px 20px;
            border-right: 1px solid var(--glass);
            display: flex;
            flex-direction: column;
        }
        .logo {
            font-size: 24px;
            font-weight: 600;
            color: var(--primary);
            margin-bottom: 40px;
            padding-left: 10px;
        }
        .nav-link {
            color: var(--text-muted);
            text-decoration: none;
            padding: 12px 15px;
            border-radius: 8px;
            margin-bottom: 5px;
            transition: 0.3s;
            display: flex;
            align-items: center;
        }
        .nav-link:hover, .nav-link.active {
            background: var(--glass);
            color: white;
        }
        .admin-badge {
            display: inline-block;
            background: linear-gradient(135deg, var(--glow-admin), var(--primary));
            color: white;
            font-size: 10px;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 20px;
            margin-left: 8px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        /* ===== MAIN CONTENT ===== */
        .main-content {
            flex: 1;
            padding: 40px;
            overflow-y: auto;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
        }

        .header-section {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 35px;
        }
        .header-section h2 {
            font-size: 26px;
            font-weight: 700;
        }
        .header-section h2 span {
            background: linear-gradient(135deg, var(--glow-admin), var(--primary));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        /* ===== STATS ROW ===== */
        .stats-row {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-bottom: 35px;
        }
        .stat-card {
            background: var(--card-bg);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid var(--glass);
            border-radius: 16px;
            padding: 28px;
            text-align: center;
            transition: 0.3s;
            position: relative;
            overflow: hidden;
        }
        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            border-radius: 16px 16px 0 0;
        }
        .stat-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 12px 30px rgba(0, 0, 0, 0.3);
        }

        .stat-card .stat-icon {
            font-size: 32px;
            margin-bottom: 12px;
            display: block;
        }
        .stat-card .stat-value {
            font-size: 42px;
            font-weight: 700;
            line-height: 1;
            margin-bottom: 6px;
        }
        .stat-card .stat-label {
            font-size: 13px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 1.5px;
        }

        /* Glow variants */
        .stat-card.glow-users {
            --glow-color: 52, 152, 219;
            border-color: rgba(52, 152, 219, 0.25);
            animation: glowPulse 3s ease-in-out infinite;
        }
        .stat-card.glow-users::before { background: var(--glow-personal); }
        .stat-card.glow-users .stat-value { color: var(--glow-personal); }
        .stat-card.glow-users:hover { border-color: var(--glow-personal); box-shadow: 0 0 25px rgba(52, 152, 219, 0.3); animation: none; }

        .stat-card.glow-active {
            --glow-color: 46, 204, 113;
            border-color: rgba(46, 204, 113, 0.25);
            animation: glowPulse 3s ease-in-out infinite;
            animation-delay: 0.5s;
        }
        .stat-card.glow-active::before { background: var(--glow-work); }
        .stat-card.glow-active .stat-value { color: var(--glow-work); }
        .stat-card.glow-active:hover { border-color: var(--glow-work); box-shadow: 0 0 25px rgba(46, 204, 113, 0.3); animation: none; }

        .stat-card.glow-system {
            --glow-color: 224, 86, 253;
            border-color: rgba(224, 86, 253, 0.25);
            animation: glowPulse 3s ease-in-out infinite;
            animation-delay: 1s;
        }
        .stat-card.glow-system::before { background: var(--glow-admin); }
        .stat-card.glow-system .stat-value { color: var(--glow-admin); }
        .stat-card.glow-system:hover { border-color: var(--glow-admin); box-shadow: 0 0 25px rgba(224, 86, 253, 0.3); animation: none; }

        /* ===== ACTION MESSAGE BANNER ===== */
        .admin-msg {
            padding: 15px 20px;
            border-radius: 12px;
            margin-bottom: 25px;
            font-weight: 500;
            font-size: 14px;
        }
        .admin-msg.success {
            background: rgba(46, 204, 113, 0.1);
            border: 1px solid #2ecc71;
            color: #2ecc71;
        }
        .admin-msg.error {
            background: rgba(255, 71, 87, 0.1);
            border: 1px solid #ff4757;
            color: #ff4757;
        }
        .admin-msg.warn {
            background: rgba(243, 156, 18, 0.1);
            border: 1px solid #f39c12;
            color: #f39c12;
        }

        /* ===== USER TABLE ===== */
        .glass-card {
            background: var(--card-bg);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid var(--glass);
            border-radius: 16px;
            padding: 28px;
            margin-bottom: 25px;
        }
        .glass-card h3 {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 6px;
        }
        .glass-card .card-desc {
            color: var(--text-muted);
            font-size: 13px;
            margin-bottom: 22px;
        }

        table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0 8px;
        }
        thead th {
            text-align: left;
            padding: 12px 16px;
            color: var(--text-muted);
            font-weight: 400;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        tbody td {
            background: rgba(255, 255, 255, 0.03);
            padding: 16px;
            border-top: 1px solid var(--glass);
            border-bottom: 1px solid var(--glass);
            font-size: 14px;
        }
        tbody td:first-child {
            border-left: 1px solid var(--glass);
            border-top-left-radius: 12px;
            border-bottom-left-radius: 12px;
        }
        tbody td:last-child {
            border-right: 1px solid var(--glass);
            border-top-right-radius: 12px;
            border-bottom-right-radius: 12px;
        }
        tbody tr:hover td {
            background: rgba(111, 66, 193, 0.06);
            border-color: rgba(111, 66, 193, 0.2);
        }

        .role-badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .role-badge.admin {
            background: rgba(224, 86, 253, 0.15);
            color: var(--glow-admin);
            border: 1px solid rgba(224, 86, 253, 0.3);
        }
        .role-badge.user {
            background: rgba(52, 152, 219, 0.12);
            color: var(--glow-personal);
            border: 1px solid rgba(52, 152, 219, 0.25);
        }

        .online-dot {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .online-dot.active { background: var(--glow-work); box-shadow: 0 0 8px rgba(46, 204, 113, 0.5); }
        .online-dot.offline { background: #475569; }

        /* Delete Button — Red Glow */
        .delete-btn {
            background: transparent;
            color: var(--glow-security);
            border: 1px solid rgba(255, 71, 87, 0.35);
            padding: 8px 16px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            font-size: 13px;
            font-family: 'Inter', sans-serif;
            transition: 0.3s;
        }
        .delete-btn:hover {
            background: rgba(255, 71, 87, 0.12);
            border-color: var(--glow-security);
            box-shadow: 0 0 20px rgba(255, 71, 87, 0.25);
            transform: translateY(-1px);
        }
        .delete-btn:disabled {
            opacity: 0.3;
            cursor: not-allowed;
        }
        .delete-btn:disabled:hover {
            background: transparent;
            border-color: rgba(255, 71, 87, 0.35);
            box-shadow: none;
            transform: none;
        }

        .empty-state {
            color: var(--text-muted);
            font-style: italic;
            padding: 40px;
            text-align: center;
        }

        @keyframes glowPulse {
            0%   { box-shadow: 0 0 8px rgba(var(--glow-color), 0.15); }
            50%  { box-shadow: 0 0 18px rgba(var(--glow-color), 0.4); }
            100% { box-shadow: 0 0 8px rgba(var(--glow-color), 0.15); }
        }
    </style>
</head>
<body>

    <%
        User currentUser = (User) session.getAttribute("user");
        if (currentUser == null) {
            response.sendRedirect("login.jsp");
            return;
        }
        // If someone hits admin.jsp directly (no request attributes), redirect through servlet
        if (request.getAttribute("totalUsers") == null) {
            response.sendRedirect("admin");
            return;
        }
    %>

    <!-- SIDEBAR -->
    <div class="sidebar">
        <div class="logo">MasterMail.ai</div>
        <a href="emails"   class="nav-link">📥 Inbox</a>
        <a href="buckets"  class="nav-link">🏷️ Buckets</a>
        <a href="advanced" class="nav-link">🛡️ Security Lab</a>
        <a href="admin"    class="nav-link active">⚙️ Admin <span class="admin-badge">Pro</span></a>
        <div style="margin-top: auto;">
            <a href="logout" class="nav-link">🚪 Logout</a>
        </div>
    </div>

    <!-- MAIN CONTENT -->
    <div class="main-content">

        <div class="header-section">
            <div>
                <h2><span>Command Center</span></h2>
                <p style="color: var(--text-muted); font-size: 14px; margin-top: 4px;">
                    Welcome, Admin <strong><%= currentUser.getName() %></strong> — Full system overview
                </p>
            </div>
        </div>

        <%-- ACTION RESULT BANNER --%>
        <%
            String adminMsg = (String) request.getAttribute("adminMsg");
            if (adminMsg != null) {
                String msgClass = adminMsg.startsWith("✅") ? "success" : adminMsg.startsWith("⚠") ? "warn" : "error";
        %>
            <div class="admin-msg <%= msgClass %>"><%= adminMsg %></div>
        <% } %>

        <!-- ===== STATS ROW ===== -->
        <div class="stats-row">
            <div class="stat-card glow-users">
                <span class="stat-icon">👥</span>
                <div class="stat-value"><%= request.getAttribute("totalUsers") %></div>
                <div class="stat-label">Total Users</div>
            </div>
            <div class="stat-card glow-active">
                <span class="stat-icon">🟢</span>
                <div class="stat-value"><%= request.getAttribute("activeUsers") %></div>
                <div class="stat-label">Active Today</div>
            </div>
            <div class="stat-card glow-system">
                <span class="stat-icon">📧</span>
                <div class="stat-value"><%= request.getAttribute("totalEmails") %></div>
                <div class="stat-label">Total Emails</div>
            </div>
        </div>

        <!-- ===== USER TABLE ===== -->
        <div class="glass-card">
            <h3>User Management</h3>
            <p class="card-desc">View all registered accounts. Delete removes the user and ALL associated emails, OTPs, buckets, and rules.</p>

            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Last Login</th>
                        <th style="text-align: center;">Action</th>
                    </tr>
                </thead>
                <tbody>
                <%
                    List<User> allUsers = (List<User>) request.getAttribute("allUsers");
                    if (allUsers != null && !allUsers.isEmpty()) {
                        for (User u : allUsers) {
                            boolean isSelf = (u.getId() == currentUser.getId());
                            boolean isRecentlyActive = false;
                            // Simple heuristic: if lastLogin string is not null, show as active
                            // (the real check is in the DB query, but we add a visual hint)
                            String loginStr = u.getLastLogin();
                %>
                    <tr>
                        <td style="color: var(--text-muted); font-weight: 600;">#<%= u.getId() %></td>
                        <td>
                            <strong><%= esc(u.getName()) %></strong>
                            <% if (isSelf) { %><span style="color: var(--glow-admin); font-size: 11px; margin-left: 6px;">(You)</span><% } %>
                        </td>
                        <td style="color: var(--text-muted);"><%= esc(u.getEmail()) %></td>
                        <td>
                            <span class="role-badge <%= u.isAdmin() ? "admin" : "user" %>">
                                <%= u.getRole() %>
                            </span>
                        </td>
                        <td>
                            <% if (loginStr != null) { %>
                                <span class="online-dot active"></span><span style="font-size: 13px;"><%= loginStr %></span>
                            <% } else { %>
                                <span class="online-dot offline"></span><span style="font-size: 13px; color: var(--text-muted);">Never</span>
                            <% } %>
                        </td>
                        <td style="text-align: center;">
                            <% if (isSelf) { %>
                                <button class="delete-btn" disabled title="Cannot delete yourself">🔒 Protected</button>
                            <% } else { %>
                                <form action="admin" method="post" style="margin: 0; display: inline;"
                                      onsubmit="return confirm('⚠️ Delete user <%= esc(u.getName()) %> (#<%= u.getId() %>)? This removes ALL their data permanently.');">
                                    <input type="hidden" name="action" value="deleteUser">
                                    <input type="hidden" name="userId" value="<%= u.getId() %>">
                                    <button type="submit" class="delete-btn">🗑️ Delete</button>
                                </form>
                            <% } %>
                        </td>
                    </tr>
                <%
                        }
                    } else {
                %>
                    <tr>
                        <td colspan="6" class="empty-state">No users found in the system.</td>
                    </tr>
                <% } %>
                </tbody>
            </table>
        </div>

    </div>

</body>
</html>

