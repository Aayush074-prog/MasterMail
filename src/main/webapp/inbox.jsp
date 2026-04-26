<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.mastermail.model.*, java.util.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;").replace("'","&#39;");
    }
    private boolean isNoReply(String sender) {
        if (sender == null) return true;
        String low = sender.toLowerCase();
        return low.contains("noreply") || low.contains("no-reply") || low.contains("no_reply")
            || low.contains("donotreply") || low.contains("do-not-reply") || low.contains("do_not_reply")
            || low.contains("mailer-daemon") || !low.contains("@");
    }
    private String extractEmail(String sender) {
        if (sender == null) return "";
        int s = sender.indexOf('<');
        int e = sender.indexOf('>');
        if (s >= 0 && e > s) return sender.substring(s + 1, e).trim();
        if (sender.contains("@")) return sender.trim();
        return "";
    }
%>
<html>
<head>
    <title>MasterMail - Inbox</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">

    <style>
        :root {
            --glass: rgba(255, 255, 255, 0.05);
            --primary: #6f42c1;
            --primary-hover: #8559da;
            --bg: #0f172a;
            --card-bg: #1e293b;
            --text-muted: #94a3b8;
            --col-decision: #ff4757;
            --col-attention: #f39c12;
            --col-ignored: #2ecc71;
            --col-all: #6f42c1;
        }

        * { box-sizing: border-box; }

        body {
            background: var(--bg);
            color: white;
            font-family: 'Inter', sans-serif;
            margin: 0;
            display: flex;
            height: 100vh;
            overflow: hidden;
        }

        /* ═══ Sidebar ═══ */
        .sidebar {
            width: 260px;
            background: #1e293b;
            padding: 30px 20px;
            border-right: 1px solid var(--glass);
            display: flex;
            flex-direction: column;
        }
        .logo { font-size: 24px; font-weight: 700; color: var(--primary); margin-bottom: 40px; padding-left: 10px; }
        .nav-link {
            color: var(--text-muted); text-decoration: none; padding: 12px 15px;
            border-radius: 8px; margin-bottom: 5px; transition: 0.3s;
            display: flex; align-items: center;
        }
        .nav-link:hover, .nav-link.active { background: var(--glass); color: white; }

        /* ═══ Main Content ═══ */
        .main-content {
            flex: 1; padding: 30px 40px; overflow-y: auto;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
        }

        .header-section { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }

        .sync-btn {
            background: linear-gradient(135deg, var(--primary), #8559da);
            color: white; border: none; padding: 10px 22px; border-radius: 10px;
            cursor: pointer; font-weight: 600; font-family: 'Inter', sans-serif;
            text-decoration: none; display: flex; align-items: center; gap: 8px;
            transition: 0.3s; font-size: 14px;
        }
        .sync-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(111,66,193,0.35); }

        .gmail-card {
            background: rgba(30, 41, 59, 0.55); backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px); border-radius: 16px;
            padding: 20px; margin-bottom: 20px;
        }

        /* ═══ Filter Tabs ═══ */
        .filter-bar {
            display: flex; gap: 0; margin-bottom: 24px;
            background: rgba(15, 23, 42, 0.6); border-radius: 14px;
            padding: 5px; border: 1px solid var(--glass);
        }
        .filter-btn {
            flex: 1; padding: 12px 16px; border: none; border-radius: 10px;
            cursor: pointer; font-family: 'Inter', sans-serif; font-weight: 600;
            font-size: 13px; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            display: flex; align-items: center; justify-content: center; gap: 8px;
            background: transparent; color: var(--text-muted);
        }
        .filter-btn:hover { color: white; background: rgba(255, 255, 255, 0.05); }
        .filter-btn.active { color: white; box-shadow: 0 4px 15px rgba(0,0,0,0.3); transform: scale(1.02); }
        .filter-btn.active[data-filter="all"] { background: linear-gradient(135deg, var(--col-all), #8559da); box-shadow: 0 4px 20px rgba(111,66,193,0.4); }
        .filter-btn.active[data-filter="needs_decision"] { background: linear-gradient(135deg, var(--col-decision), #ff6b81); box-shadow: 0 4px 20px rgba(255,71,87,0.4); }
        .filter-btn.active[data-filter="needs_attention"] { background: linear-gradient(135deg, var(--col-attention), #f5b041); box-shadow: 0 4px 20px rgba(243,156,18,0.4); }
        .filter-btn.active[data-filter="ignored_safely"] { background: linear-gradient(135deg, var(--col-ignored), #58d68d); box-shadow: 0 4px 20px rgba(46,204,113,0.4); }
        .filter-count { background: rgba(255,255,255,0.15); padding: 2px 8px; border-radius: 20px; font-size: 11px; min-width: 22px; text-align: center; }
        .filter-btn.active .filter-count { background: rgba(255,255,255,0.25); }

        /* ═══ Search Bar ═══ */
        .search-bar-wrap {
            position: relative; margin-bottom: 16px;
        }
        .search-icon {
            position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
            font-size: 14px; pointer-events: none;
        }
        .inbox-search {
            width: 100%; box-sizing: border-box;
            background: rgba(30, 41, 59, 0.7); color: white;
            border: 1px solid rgba(255,255,255,0.1); border-radius: 12px;
            padding: 11px 16px 11px 40px; font-size: 14px;
            outline: none; transition: border-color 0.2s, box-shadow 0.2s;
        }
        .inbox-search::placeholder { color: var(--text-muted); }
        .inbox-search:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(111,66,193,0.15);
        }

        /* ═══ Email Cards ═══ */
        .email-card {
            background: rgba(30, 41, 59, 0.55); backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px); border: 1px solid var(--glass);
            border-radius: 16px; margin-bottom: 12px;
            transition: all 0.3s ease; overflow: hidden;
        }
        .email-card:hover { border-color: var(--primary); box-shadow: 0 10px 25px rgba(0,0,0,0.2); }
        .email-card.hidden { display: none !important; }
        .email-card.search-hidden { display: none !important; }
        .email-card.expanded { border-color: var(--primary); box-shadow: 0 0 25px rgba(111,66,193,0.2); }

        .email-card.cat-needs_decision { border-left: 3px solid var(--col-decision); background: linear-gradient(135deg, rgba(30,41,59,0.55) 0%, rgba(255,71,87,0.06) 100%); }
        .email-card.cat-needs_decision:hover, .email-card.cat-needs_decision.expanded { border-color: var(--col-decision); box-shadow: 0 0 20px rgba(255,71,87,0.25); }

        .email-card.cat-needs_attention { border-left: 3px solid var(--col-attention); background: linear-gradient(135deg, rgba(30,41,59,0.55) 0%, rgba(243,156,18,0.06) 100%); }
        .email-card.cat-needs_attention:hover, .email-card.cat-needs_attention.expanded { border-color: var(--col-attention); box-shadow: 0 0 20px rgba(243,156,18,0.25); }

        .email-card.cat-ignored_safely { border-left: 3px solid var(--col-ignored); background: linear-gradient(135deg, rgba(30,41,59,0.55) 0%, rgba(46,204,113,0.06) 100%); }
        .email-card.cat-ignored_safely:hover, .email-card.cat-ignored_safely.expanded { border-color: var(--col-ignored); box-shadow: 0 0 20px rgba(46,204,113,0.25); }

        /* Summary row — clickable */
        .email-summary {
            display: flex; justify-content: space-between; align-items: center;
            padding: 20px; cursor: pointer; transition: background 0.2s;
        }
        .email-summary:hover { background: rgba(255,255,255,0.02); }

        .mail-info { flex: 1; min-width: 0; }
        .mail-info h4 { margin: 6px 0 5px 0; font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .mail-info p { margin: 0; color: var(--text-muted); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

        .cat-badge { display: inline-block; padding: 3px 10px; border-radius: 20px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }
        .cat-badge.decision { background: rgba(255,71,87,0.15); color: var(--col-decision); }
        .cat-badge.attention { background: rgba(243,156,18,0.15); color: var(--col-attention); }
        .cat-badge.ignored { background: rgba(46,204,113,0.15); color: var(--col-ignored); }
        .bucket-tag { display: inline-block; color: var(--primary); font-size: 11px; font-weight: 600; margin-left: 8px; }

        .card-actions { display: flex; gap: 8px; flex-shrink: 0; margin-left: 15px; align-items: center; }
        .priority-select {
            background: rgba(255,255,255,0.05); color: var(--text-muted);
            border: 1px solid rgba(255,255,255,0.1); border-radius: 8px;
            padding: 6px 10px; font-size: 12px; cursor: pointer;
            transition: border-color 0.2s, color 0.2s;
        }
        .priority-select:hover { border-color: var(--primary); color: var(--text-primary); }
        .priority-select option { background: #1e2532; color: var(--text-primary); }
        .expand-arrow { color: var(--text-muted); font-size: 18px; transition: transform 0.3s; margin-left: 5px; }
        .email-card.expanded .expand-arrow { transform: rotate(180deg); }

        .magic-btn {
            background: var(--primary); color: white; border: none;
            padding: 9px 16px; border-radius: 8px; cursor: pointer;
            font-weight: 600; font-size: 13px; font-family: 'Inter', sans-serif; transition: 0.3s;
        }
        .magic-btn:hover { background: var(--primary-hover); transform: translateY(-1px); }

        .delete-btn {
            background: transparent; color: #ef4444;
            border: 1px solid rgba(239,68,68,0.3); padding: 9px 12px;
            border-radius: 8px; cursor: pointer; font-size: 13px; transition: 0.3s;
        }
        .delete-btn:hover { background: rgba(239,68,68,0.1); border-color: #ef4444; }

        /* ═══ Email Detail Panel (Expandable) ═══ */
        .email-detail {
            display: none;
            border-top: 1px solid var(--glass);
            padding: 0 20px 20px 20px;
            animation: slideDown 0.3s ease;
        }
        .email-card.expanded .email-detail { display: block; }

        @keyframes slideDown {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .email-body-scroll {
            max-height: 300px;
            overflow-y: auto;
            background: rgba(15, 23, 42, 0.5);
            border: 1px solid var(--glass);
            border-radius: 12px;
            padding: 18px;
            margin-top: 16px;
            font-size: 14px;
            line-height: 1.7;
            color: #cbd5e1;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        .email-body-scroll::-webkit-scrollbar { width: 6px; }
        .email-body-scroll::-webkit-scrollbar-track { background: transparent; }
        .email-body-scroll::-webkit-scrollbar-thumb { background: rgba(111,66,193,0.3); border-radius: 3px; }
        .email-body-scroll::-webkit-scrollbar-thumb:hover { background: rgba(111,66,193,0.5); }

        /* ═══ Reply Section ═══ */
        .reply-section {
            margin-top: 16px;
            background: rgba(15, 23, 42, 0.4);
            border: 1px solid var(--glass);
            border-radius: 12px;
            padding: 16px;
        }
        .reply-section label {
            display: block; font-size: 12px; color: var(--text-muted);
            text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; font-weight: 600;
        }
        .reply-textarea {
            width: 100%; min-height: 100px; max-height: 200px;
            background: rgba(15, 23, 42, 0.7); border: 1px solid var(--glass);
            color: white; padding: 14px; border-radius: 10px;
            font-size: 14px; font-family: 'Inter', sans-serif;
            line-height: 1.6; resize: vertical; outline: none;
            transition: border-color 0.3s, box-shadow 0.3s;
        }
        .reply-textarea:focus { border-color: var(--primary); box-shadow: 0 0 15px rgba(111,66,193,0.2); }

        .reply-actions { display: flex; gap: 10px; margin-top: 12px; align-items: center; }

        .send-btn {
            background: linear-gradient(135deg, #2ecc71, #27ae60);
            color: white; border: none; padding: 10px 22px; border-radius: 10px;
            cursor: pointer; font-weight: 600; font-size: 14px;
            font-family: 'Inter', sans-serif; transition: 0.3s;
            display: flex; align-items: center; gap: 6px;
        }
        .send-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(46,204,113,0.35); }

        .noreply-notice {
            color: var(--text-muted); font-size: 13px;
            display: flex; align-items: center; gap: 8px;
            padding: 14px 18px;
            background: rgba(255,255,255,0.02);
            border: 1px dashed rgba(255,255,255,0.1);
            border-radius: 10px; margin-top: 16px;
        }

        /* ═══ Status Banners ═══ */
        .otp-notif {
            background: rgba(255,193,7,0.08); border: 1px solid rgba(255,193,7,0.3);
            padding: 12px 16px; border-radius: 12px; margin-bottom: 16px;
            color: #ffc107; animation: pulse 2s infinite; font-size: 14px;
            display: flex; justify-content: space-between; align-items: center; gap: 12px;
        }
        .otp-notif-inner { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
        .otp-dismiss-btn {
            background: transparent; border: none; color: rgba(255,193,7,0.5);
            cursor: pointer; font-size: 20px; line-height: 1; padding: 2px 6px;
            border-radius: 4px; flex-shrink: 0; transition: color 0.2s;
        }
        .otp-dismiss-btn:hover { color: #ffc107; }
        @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.6; } 100% { opacity: 1; } }

        /* ═══ Click-to-Copy OTP Pill ═══ */
        .otp-copy-pill {
            display: inline-flex; align-items: center; gap: 6px;
            background: rgba(255,193,7,0.18); border: 1px solid rgba(255,193,7,0.5);
            color: #ffc107; padding: 4px 14px; border-radius: 8px;
            cursor: pointer; user-select: none;
            transition: background 0.2s, border-color 0.2s, transform 0.15s;
        }
        .otp-copy-pill:hover { background: rgba(255,193,7,0.28); border-color: rgba(255,193,7,0.7); transform: translateY(-1px); }
        .otp-copy-pill.copied { background: rgba(46,204,113,0.18); border-color: rgba(46,204,113,0.5); color: #2ecc71; }
        .otp-code-text { font-weight: 700; letter-spacing: 3px; font-size: 15px; }
        .otp-copy-icon { font-size: 12px; opacity: 0.55; }
        .otp-copy-pill.copied .otp-copy-icon { display: none; }

        .empty-state { text-align: center; padding: 60px 20px; color: var(--text-muted); }
        .empty-state .emoji { font-size: 48px; margin-bottom: 15px; }

        .feed-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
        .feed-header h3 { margin: 0; font-weight: 600; font-size: 16px; }
        .feed-count { color: var(--text-muted); font-size: 13px; }

        .status-banner {
            padding: 14px 18px; border-radius: 12px; margin-bottom: 16px;
            font-weight: 500; font-size: 14px;
        }

        /* ═══ Pagination ═══ */
        .pagination {
            display: flex; align-items: center; justify-content: center;
            gap: 12px; margin-top: 28px; padding-bottom: 20px;
        }
        .page-btn {
            background: rgba(111,66,193,0.15); border: 1px solid rgba(111,66,193,0.3);
            color: var(--primary-hover); text-decoration: none;
            padding: 10px 20px; border-radius: 10px; font-weight: 600; font-size: 14px;
            font-family: 'Inter', sans-serif; transition: 0.2s;
        }
        .page-btn:hover { background: rgba(111,66,193,0.3); transform: translateY(-1px); }
        .page-btn.disabled { opacity: 0.35; pointer-events: none; }
        .page-info { color: var(--text-muted); font-size: 13px; }

        /* ═══ Read / Unread / Replied States ═══ */
        .email-card.is-unread .mail-info h4 {
            font-weight: 700;
            color: #ffffff;
        }
        .email-card.is-unread .mail-info > p {
            color: #cbd5e1;
        }
        .email-card.is-read .mail-info h4 {
            font-weight: 400;
            color: #94a3b8;
        }
        .email-card.is-read .mail-info > p {
            color: #64748b;
        }
        .unread-dot {
            display: inline-block;
            width: 8px; height: 8px;
            border-radius: 50%;
            background: var(--primary);
            box-shadow: 0 0 6px rgba(111,66,193,0.9), 0 0 14px rgba(111,66,193,0.5);
            margin-left: 8px;
            vertical-align: middle;
            flex-shrink: 0;
            animation: dotGlow 2s ease-in-out infinite;
        }
        @keyframes dotGlow {
            0%, 100% { box-shadow: 0 0 6px rgba(111,66,193,0.9), 0 0 14px rgba(111,66,193,0.5); }
            50%       { box-shadow: 0 0 10px rgba(111,66,193,1),   0 0 22px rgba(111,66,193,0.7); }
        }
        .replied-badge {
            display: inline-flex; align-items: center; gap: 3px;
            font-size: 11px; font-weight: 600;
            color: #2ecc71;
            background: rgba(46,204,113,0.12);
            border: 1px solid rgba(46,204,113,0.25);
            border-radius: 20px;
            padding: 2px 8px;
            margin-left: 8px;
            vertical-align: middle;
        }

        /* ═══ Sync Overlay ═══ */
        #sync-overlay {
            display: none; position: fixed; inset: 0;
            background: rgba(15, 23, 42, 0.88);
            z-index: 999; flex-direction: column;
            align-items: center; justify-content: center; gap: 16px;
            backdrop-filter: blur(4px);
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .spin-icon {
            font-size: 44px;
            display: inline-block;
            animation: spin 0.9s linear infinite;
        }
    </style>
</head>
<body>

    <div id="sync-overlay">
        <div class="spin-icon">⟳</div>
        <p style="color:white; font-size:18px; font-weight:600; margin:0;">Syncing Gmail…</p>
        <p style="color:var(--text-muted); font-size:14px; margin:0;">Connecting to IMAP, this may take a few seconds</p>
    </div>

    <div class="sidebar">
        <div class="logo">MasterMail.ai</div>
        <a href="emails" class="nav-link active">📥 Inbox</a>
        <a href="replies" class="nav-link">💬 Replies</a>
        <a href="buckets" class="nav-link">🏷️ Buckets</a>
        <a href="advanced" class="nav-link">🛡️ Security Lab</a>
        <%
            User sideUser = (User) session.getAttribute("user");
            if (sideUser != null && sideUser.isAdmin()) {
        %>
            <a href="admin" class="nav-link">⚙️ Admin</a>
        <% } %>
        <div style="margin-top: auto;">
            <a href="logout" class="nav-link">🚪 Logout</a>
        </div>
    </div>

    <div class="main-content">
        <%
            User currentUser = (User) session.getAttribute("user");
            List<Email> emailList = (List<Email>) request.getAttribute("emailList");

            int totalCount   = request.getAttribute("totalCount")  != null ? (Integer) request.getAttribute("totalCount")  : (emailList != null ? emailList.size() : 0);
            int currentPage  = request.getAttribute("currentPage") != null ? (Integer) request.getAttribute("currentPage") : 1;
            int totalPages   = request.getAttribute("totalPages")  != null ? (Integer) request.getAttribute("totalPages")  : 1;

            int decisionCount = 0, attentionCount = 0, ignoredCount = 0;
            if (emailList != null) {
                for (Email e : emailList) {
                    String cat = e.getCategory();
                    if ("needs_decision".equals(cat)) decisionCount++;
                    else if ("needs_attention".equals(cat)) attentionCount++;
                    else ignoredCount++;
                }
            }
            int pageCount = (emailList != null) ? emailList.size() : 0;
        %>

        <%-- ═══ Header ═══ --%>
        <div class="header-section">
            <h2 style="margin: 0; font-size: 22px;">Welcome back, <%= currentUser.getName() %></h2>
            <a href="emails?action=sync" class="sync-btn"
               onclick="document.getElementById('sync-overlay').style.display='flex';">🔄 Sync Gmail</a>
        </div>

        <%-- ═══ Gmail Credentials Card ═══ --%>
        <div class="gmail-card" style="border: 1px solid <%= currentUser.hasGmailLinked() ? "rgba(46, 204, 113, 0.3)" : "rgba(243, 156, 18, 0.3)" %>;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                <div>
                    <strong style="font-size: 15px;">
                        <%= currentUser.hasGmailLinked() ? "🔗 Gmail Linked" : "⚠️ Link Your Gmail" %>
                    </strong>
                    <p style="color: var(--text-muted); font-size: 12px; margin: 4px 0 0 0;">
                        <%= currentUser.hasGmailLinked()
                                ? "Syncing from: " + currentUser.getGmailEmail()
                                : "Enter your Gmail & App Password to sync your own inbox" %>
                    </p>
                </div>
                <button onclick="document.getElementById('gmail-form').style.display =
                    document.getElementById('gmail-form').style.display === 'none' ? 'flex' : 'none'"
                    style="background: transparent; border: 1px solid var(--glass); color: var(--text-muted);
                           padding: 8px 14px; border-radius: 8px; cursor: pointer; font-family: 'Inter', sans-serif;
                           font-size: 12px; transition: 0.3s;">
                    <%= currentUser.hasGmailLinked() ? "✏️ Update" : "➕ Setup" %>
                </button>
            </div>
            <form id="gmail-form" action="emails" method="post"
                  style="display: <%= currentUser.hasGmailLinked() ? "none" : "flex" %>;
                         gap: 10px; align-items: flex-end; flex-wrap: wrap;">
                <input type="hidden" name="action" value="saveGmail">
                <div style="flex: 1; min-width: 200px;">
                    <label style="font-size: 11px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px;">Gmail Address</label>
                    <input type="email" name="gmailEmail" placeholder="you@gmail.com"
                           value="<%= currentUser.getGmailEmail() != null ? currentUser.getGmailEmail() : "" %>"
                           required
                           style="width: 100%; background: rgba(15, 23, 42, 0.7); border: 1px solid var(--glass);
                                  color: white; padding: 10px 14px; border-radius: 8px; font-size: 14px;
                                  font-family: 'Inter', sans-serif; margin-top: 4px; outline: none;">
                </div>
                <div style="flex: 1; min-width: 200px;">
                    <label style="font-size: 11px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px;">App Password (16 chars)</label>
                    <input type="password" name="appPassword" placeholder="xxxx xxxx xxxx xxxx"
                           required minlength="16"
                           style="width: 100%; background: rgba(15, 23, 42, 0.7); border: 1px solid var(--glass);
                                  color: white; padding: 10px 14px; border-radius: 8px; font-size: 14px;
                                  font-family: 'Inter', sans-serif; margin-top: 4px; outline: none;">
                </div>
                <button type="submit"
                        style="background: linear-gradient(135deg, var(--primary), #8559da); color: white;
                               border: none; padding: 10px 20px; border-radius: 8px; cursor: pointer;
                               font-weight: 600; font-family: 'Inter', sans-serif; white-space: nowrap;">
                    💾 Save & Link
                </button>
            </form>
        </div>

        <%-- ═══ Auto-Draft Notification Banner ═══ --%>
        <%
            java.util.List<String[]> autoDrafts = new com.mastermail.dao.AdvancedDAO().getAutoDraftedReplies(currentUser.getId());
            if (autoDrafts != null && !autoDrafts.isEmpty()) {
        %>
        <div style="background: rgba(46, 204, 113, 0.08); border: 1px solid rgba(46, 204, 113, 0.3);
                    border-radius: 12px; padding: 14px 18px; margin-bottom: 20px;
                    display: flex; justify-content: space-between; align-items: center;">
            <div>
                <strong style="font-size: 14px; color: #2ecc71;">
                    🤖 <%= autoDrafts.size() %> Auto-Reply Draft<%= autoDrafts.size() > 1 ? "s" : "" %> Awaiting Approval
                </strong>
                <p style="color: var(--text-muted); font-size: 12px; margin: 4px 0 0 0;">
                    Your auto-reply rules have generated replies ready to review and send
                </p>
            </div>
            <a href="replies" style="background: linear-gradient(135deg, #2ecc71, #27ae60); color: white;
                                     padding: 10px 20px; border-radius: 10px; text-decoration: none;
                                     font-weight: 600; font-size: 13px; white-space: nowrap;">
                Review &amp; Send →
            </a>
        </div>
        <% } %>

        <%-- ═══ Sync Result Banner ═══ --%>
        <%
            String syncResult = (String) request.getAttribute("syncResult");
            if (syncResult != null) {
                boolean isSuccess = syncResult.startsWith("✅");
        %>
            <div class="status-banner" style="background: <%= isSuccess ? "rgba(46,204,113,0.1)" : "rgba(255,71,87,0.1)" %>;
                        border: 1px solid <%= isSuccess ? "#2ecc71" : "#ff4757" %>;
                        color: <%= isSuccess ? "#2ecc71" : "#ff4757" %>;">
                <%= syncResult %>
            </div>
        <% } %>

        <%-- ═══ Reply Status Banner ═══ --%>
        <%
            String replyStatus = request.getParameter("replyStatus");
            if ("sent".equals(replyStatus)) {
        %>
            <div class="status-banner" style="background: rgba(46,204,113,0.1); border: 1px solid #2ecc71; color: #2ecc71;">
                ✅ Reply sent successfully!
            </div>
        <% } else if ("failed".equals(replyStatus) || "authfail".equals(replyStatus)) { %>
            <div class="status-banner" style="background: rgba(255,71,87,0.1); border: 1px solid #ff4757; color: #ff4757;">
                ❌ Failed to send reply — please check your Gmail credentials.
            </div>
        <% } else if ("invalid".equals(replyStatus)) { %>
            <div class="status-banner" style="background: rgba(243,156,18,0.1); border: 1px solid #f39c12; color: #f39c12;">
                ⚠️ Could not determine recipient email address.
            </div>
        <% } %>

        <%-- ═══ OTP Alert Bar ═══ --%>
        <%
            List<String> activeOTPs = (List<String>) request.getAttribute("freshOTPs");
            if (activeOTPs != null && !activeOTPs.isEmpty()) {
                for (String otp : activeOTPs) {
                    // Split "167890 (from sender)" → code + sender
                    String otpCode = otp, otpSender = "";
                    int fromIdx = otp.indexOf(" (from ");
                    if (fromIdx > 0) {
                        otpCode   = otp.substring(0, fromIdx).trim();
                        otpSender = otp.substring(fromIdx + 7, otp.length() - 1);
                    }
        %>
            <div class="otp-notif" data-otp-key="<%= esc(otp) %>">
                <div class="otp-notif-inner">
                    <strong>🛡️ SECURITY ALERT:</strong>
                    <span style="color:rgba(255,193,7,0.8);">Fresh OTP Detected</span>
                    <span class="otp-copy-pill" onclick="copyOtp(this)" data-otp-code="<%= esc(otpCode) %>">
                        <span class="otp-code-text"><%= esc(otpCode) %></span>
                        <span class="otp-copy-icon">📋</span>
                    </span>
                    <% if (!otpSender.isEmpty()) { %>
                        <span style="color:rgba(255,193,7,0.5);font-size:12px;">from <%= esc(otpSender) %></span>
                    <% } %>
                </div>
                <button class="otp-dismiss-btn" onclick="dismissOtp(this)" title="Dismiss">&#x2715;</button>
            </div>
        <%      }
            }
        %>

        <%-- ═══ Filter Tabs ═══ --%>
        <div class="filter-bar">
            <button class="filter-btn active" data-filter="all" onclick="filterEmails('all', this)">
                📬 All <span class="filter-count"><%= totalCount %></span>
            </button>
            <button class="filter-btn" data-filter="needs_decision" onclick="filterEmails('needs_decision', this)">
                🔴 Needs Decision <span class="filter-count"><%= decisionCount %></span>
            </button>
            <button class="filter-btn" data-filter="needs_attention" onclick="filterEmails('needs_attention', this)">
                🟡 Needs Attention <span class="filter-count"><%= attentionCount %></span>
            </button>
            <button class="filter-btn" data-filter="ignored_safely" onclick="filterEmails('ignored_safely', this)">
                🟢 Ignored Safely <span class="filter-count"><%= ignoredCount %></span>
            </button>
        </div>

        <%-- ═══ Search Bar ═══ --%>
        <div class="search-bar-wrap">
            <span class="search-icon">🔍</span>
            <input type="text" id="inboxSearch" class="inbox-search"
                   placeholder="Search by subject, sender, or keyword..."
                   oninput="searchEmails(this.value)">
        </div>

        <%-- ═══ Feed Header ═══ --%>
        <div class="feed-header">
            <h3>Your Feed</h3>
            <%
                int rangeStart = (currentPage - 1) * 25 + 1;
                int rangeEnd   = Math.min(currentPage * 25, totalCount);
            %>
            <span class="feed-count" id="visibleCount">
                <%= totalCount == 0 ? "0 emails" : rangeStart + "–" + rangeEnd + " of " + totalCount %>
            </span>
        </div>

        <%-- ═══ Email Cards with Expandable Detail ═══ --%>
        <%
            if (emailList != null && !emailList.isEmpty()) {
                int cardIndex = 0;
                for (Email mail : emailList) {
                    String category = mail.getCategory();
                    if (category == null) category = "ignored_safely";

                    String catClass, badgeClass, badgeLabel;
                    switch (category) {
                        case "needs_decision":
                            catClass = "cat-needs_decision"; badgeClass = "decision"; badgeLabel = "Needs Decision"; break;
                        case "needs_attention":
                            catClass = "cat-needs_attention"; badgeClass = "attention"; badgeLabel = "Needs Attention"; break;
                        default:
                            catClass = "cat-ignored_safely"; badgeClass = "ignored"; badgeLabel = "Ignored Safely";
                            category = "ignored_safely"; break;
                    }

                    String bucketName = mail.getBucketName();
                    String senderRaw = mail.getSender();
                    boolean noReply = isNoReply(senderRaw);
                    String recipientEmail = extractEmail(senderRaw);
                    boolean emailIsReplied = mail.isReplied();
                    boolean emailIsRead    = mail.isRead();
                    String readClass = emailIsReplied ? "is-read is-replied" : (emailIsRead ? "is-read" : "is-unread");
                    cardIndex++;
        %>
        <div class="email-card <%= catClass %> <%= readClass %>" data-category="<%= category %>" id="card-<%= cardIndex %>" data-email-id="<%= mail.getId() %>" data-subject="<%= esc(mail.getSubject()) %>" data-sender="<%= esc(mail.getSender()) %>">
            <%-- ── Summary Row (clickable) ── --%>
            <div class="email-summary" onclick="toggleDetail(<%= cardIndex %>, event)">
                <div class="mail-info">
                    <div>
                        <span class="cat-badge <%= badgeClass %>"><%= badgeLabel %></span>
                        <% if (bucketName != null && !"Inbox".equals(bucketName)) { %>
                            <span class="bucket-tag">#<%= bucketName %></span>
                        <% } %>
                    </div>
                    <h4>
                        <%= mail.getSubject() %>
                        <% if (!emailIsRead && !emailIsReplied) { %><span class="unread-dot"></span><% } %>
                        <% if (emailIsReplied) { %><span class="replied-badge">↩ Replied</span><% } %>
                    </h4>
                    <p>From: <strong><%= mail.getSender() %></strong> &bull; <%= mail.getDate() %></p>
                </div>

                <div class="card-actions">
                    <select class="priority-select" onclick="event.stopPropagation()"
                            onchange="updatePriority(<%= mail.getId() %>, this)">
                        <option value="">Move to...</option>
                        <option value="needs_decision">Needs Decision</option>
                        <option value="needs_attention">Needs Attention</option>
                        <option value="ignored_safely">Ignored Safely</option>
                    </select>
                    <form action="advanced" method="post" style="margin:0;" onclick="event.stopPropagation();">
                        <input type="hidden" name="action" value="safeDelete">
                        <input type="hidden" name="emailId" value="<%= mail.getId() %>">
                        <button type="submit" class="delete-btn">🗑️</button>
                    </form>
                    <span class="expand-arrow">▼</span>
                </div>
            </div>

            <%-- ── Detail Panel (hidden by default) ── --%>
            <div class="email-detail">
                <div class="email-body-scroll"><%= esc(mail.getBody()) %></div>

                <% if (noReply) { %>
                    <div class="noreply-notice">
                        🚫 This sender (<strong style="color: white; margin: 0 4px;"><%= esc(senderRaw) %></strong>) does not accept replies.
                    </div>
                <% } else { %>
                    <div class="reply-section">
                        <label>↩️ Reply to <%= esc(senderRaw) %></label>
                        <%-- Two sibling forms — never nested --%>
                        <form id="send-form-<%= cardIndex %>" action="send-reply" method="post">
                            <input type="hidden" name="recipient" value="<%= esc(senderRaw) %>">
                            <input type="hidden" name="subject" value="Re: <%= esc(mail.getSubject()) %>">
                            <input type="hidden" name="emailId" value="<%= mail.getId() %>">
                            <textarea class="reply-textarea" name="finalMessage"
                                      placeholder="Type your reply here..."></textarea>
                        </form>
                        <form id="ai-form-<%= cardIndex %>" action="magic-reply" method="post">
                            <input type="hidden" name="emailBody" value="<%= esc(mail.getBody()) %>">
                            <input type="hidden" name="senderName" value="<%= esc(mail.getSender()) %>">
                            <input type="hidden" name="emailId" value="<%= mail.getId() %>">
                        </form>
                        <div class="reply-actions">
                            <button type="submit" form="send-form-<%= cardIndex %>" class="send-btn">📤 Send Reply</button>
                            <button type="submit" form="ai-form-<%= cardIndex %>" class="magic-btn">✨ AI Reply</button>
                            <span style="color: var(--text-muted); font-size: 12px;">
                                Sending from: <%= currentUser.getGmailEmail() %>
                            </span>
                        </div>
                    </div>
                <% } %>
            </div>
        </div>
        <%
                }
            } else {
        %>
            <div class="empty-state">
                <div class="emoji">☕</div>
                <p>Your inbox is quiet. Hit <strong>Sync Gmail</strong> to pull in your emails!</p>
            </div>
        <% } %>

        <%-- ═══ Pagination Bar ═══ --%>
        <% if (totalPages > 1) { %>
        <div class="pagination">
            <% if (currentPage > 1) { %>
                <a href="emails?page=<%= currentPage - 1 %>" class="page-btn">← Previous</a>
            <% } else { %>
                <span class="page-btn disabled">← Previous</span>
            <% } %>

            <span class="page-info">Page <%= currentPage %> of <%= totalPages %></span>

            <% if (currentPage < totalPages) { %>
                <a href="emails?page=<%= currentPage + 1 %>" class="page-btn">Next →</a>
            <% } else { %>
                <span class="page-btn disabled">Next →</span>
            <% } %>
        </div>
        <% } %>
    </div>

    <script>
        function copyOtp(pill) {
            if (pill.classList.contains('copied')) return;
            var code = pill.getAttribute('data-otp-code');
            var codeSpan = pill.querySelector('.otp-code-text');
            navigator.clipboard.writeText(code).catch(function() {
                var ta = document.createElement('textarea');
                ta.value = code; ta.style.cssText = 'position:fixed;opacity:0;';
                document.body.appendChild(ta); ta.select(); document.execCommand('copy');
                document.body.removeChild(ta);
            });
            pill.classList.add('copied');
            codeSpan.textContent = 'Copied! ✔';
            setTimeout(function() { pill.classList.remove('copied'); codeSpan.textContent = code; }, 2000);
        }

        function dismissOtp(btn) {
            var banner = btn.closest('.otp-notif');
            var otpKey = banner.getAttribute('data-otp-key');
            banner.remove();
            fetch('dismiss-otp', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'otpKey=' + encodeURIComponent(otpKey)
            });
        }

        function toggleDetail(index, event) {
            if (event.target.closest('form') || event.target.closest('button')) return;

            var card = document.getElementById('card-' + index);
            var isExpanding = !card.classList.contains('expanded');
            card.classList.toggle('expanded');

            // Mark as read when opening an unread email — fire-and-forget AJAX
            if (isExpanding && card.classList.contains('is-unread')) {
                var emailId = card.getAttribute('data-email-id');
                if (emailId) {
                    fetch('mark-read', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                        body: 'emailId=' + encodeURIComponent(emailId)
                    });
                    // Immediately update UI without waiting for the server
                    card.classList.remove('is-unread');
                    card.classList.add('is-read');
                    var dot = card.querySelector('.unread-dot');
                    if (dot) dot.remove();
                }
            }
        }

        // ── Deep-link: auto-expand email highlighted from Security Lab ──
        (function() {
            var highlightId = '<%= request.getParameter("highlight") != null ? request.getParameter("highlight").replaceAll("[^0-9]", "") : "" %>';
            if (!highlightId) return;
            document.addEventListener('DOMContentLoaded', function() {
                var card = document.querySelector('[data-email-id="' + highlightId + '"]');
                if (!card) return;
                card.scrollIntoView({ behavior: 'smooth', block: 'center' });
                if (!card.classList.contains('expanded')) {
                    card.classList.add('expanded');
                    // Mark as read if needed
                    if (card.classList.contains('is-unread')) {
                        var emailId = card.getAttribute('data-email-id');
                        fetch('mark-read', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                            body: 'emailId=' + encodeURIComponent(emailId)
                        });
                        card.classList.remove('is-unread');
                        card.classList.add('is-read');
                        var dot = card.querySelector('.unread-dot');
                        if (dot) dot.remove();
                    }
                }
                // Brief highlight pulse
                card.style.boxShadow = '0 0 0 2px var(--primary), 0 0 20px rgba(111,66,193,0.4)';
                setTimeout(function() { card.style.boxShadow = ''; }, 2500);
            });
        })();

        function searchEmails(query) {
            var q = query.trim().toLowerCase();
            var cards = document.querySelectorAll('.email-card');
            var visible = 0;
            cards.forEach(function(card) {
                var subject = (card.getAttribute('data-subject') || '').toLowerCase();
                var sender  = (card.getAttribute('data-sender')  || '').toLowerCase();
                var matchesSearch = !q || subject.includes(q) || sender.includes(q);
                card.classList.toggle('search-hidden', !matchesSearch);
                var hiddenByFilter = card.classList.contains('hidden');
                if (matchesSearch && !hiddenByFilter) visible++;
            });
            document.getElementById('visibleCount').textContent = visible + ' email(s)';
        }

        function updatePriority(emailId, selectEl) {
            var newPriority = selectEl.value;
            if (!newPriority) return;
            var card = selectEl.closest('.email-card');
            fetch('update-priority', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'emailId=' + encodeURIComponent(emailId) + '&newPriority=' + encodeURIComponent(newPriority)
            }).then(function(resp) {
                if (resp.ok) {
                    var labels = { needs_decision: 'Needs Decision', needs_attention: 'Needs Attention', ignored_safely: 'Ignored Safely' };
                    var classes = { needs_decision: 'decision', needs_attention: 'attention', ignored_safely: 'ignored' };
                    card.setAttribute('data-category', newPriority);
                    card.className = card.className.replace(/cat-\S+/, 'cat-' + newPriority);
                    var badge = card.querySelector('.cat-badge');
                    if (badge) {
                        badge.textContent = labels[newPriority];
                        badge.className = 'cat-badge ' + classes[newPriority];
                    }
                }
                selectEl.value = '';
            }).catch(function() { selectEl.value = ''; });
        }

        function filterEmails(category, clickedBtn) {
            document.querySelectorAll('.filter-btn').forEach(function(btn) { btn.classList.remove('active'); });
            clickedBtn.classList.add('active');

            var cards = document.querySelectorAll('.email-card');
            var visibleCount = 0;
            cards.forEach(function(card) {
                var matchesCategory = category === 'all' || card.getAttribute('data-category') === category;
                if (matchesCategory) {
                    card.classList.remove('hidden');
                    if (!card.classList.contains('search-hidden')) visibleCount++;
                } else {
                    card.classList.add('hidden');
                    card.classList.remove('expanded');
                }
            });
            document.getElementById('visibleCount').textContent = visibleCount + ' email(s)';
        }
    </script>

</body>
</html>

