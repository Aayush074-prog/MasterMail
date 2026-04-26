<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.mastermail.model.*, java.util.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;").replace("'","&#39;");
    }
    private String trunc(String s, int max) {
        if (s == null) return "";
        return s.length() > max ? s.substring(0, max) + "…" : s;
    }
%>
<html>
<head>
    <title>MasterMail — Security Lab</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --glass: rgba(255, 255, 255, 0.05);
            --primary: #6f42c1;
            --primary-hover: #8559da;
            --bg: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.55);
            --text-muted: #94a3b8;
            --red: #ff4757;
            --amber: #f39c12;
            --blue: #3498db;
            --green: #2ecc71;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            background: var(--bg);
            color: white;
            font-family: 'Inter', sans-serif;
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
            flex-shrink: 0;
        }
        .logo { font-size: 24px; font-weight: 700; color: var(--primary); margin-bottom: 40px; padding-left: 10px; }
        .nav-link {
            color: var(--text-muted); text-decoration: none; padding: 12px 15px;
            border-radius: 8px; margin-bottom: 5px; transition: 0.3s; display: flex; align-items: center;
        }
        .nav-link:hover, .nav-link.active { background: var(--glass); color: white; }

        /* ═══ Main Content ═══ */
        .main-content {
            flex: 1;
            padding: 36px 40px;
            overflow-y: auto;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
        }

        .page-title { font-size: 22px; font-weight: 700; margin-bottom: 28px; }

        /* ═══ Glass Card ═══ */
        .glass-card {
            background: var(--card-bg);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid var(--glass);
            border-radius: 16px;
            padding: 24px 28px;
            margin-bottom: 24px;
            transition: border-color 0.3s, box-shadow 0.3s;
        }
        .glass-card:hover {
            border-color: rgba(111, 66, 193, 0.3);
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .card-header { display: flex; align-items: center; gap: 12px; margin-bottom: 5px; }
        .card-icon {
            width: 36px; height: 36px; border-radius: 10px;
            display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0;
        }
        .card-icon.red    { background: rgba(255, 71, 87, 0.15); }
        .card-icon.purple { background: rgba(111, 66, 193, 0.15); }
        .card-icon.amber  { background: rgba(243, 156, 18, 0.15); }
        .card-header h3 { font-size: 17px; font-weight: 600; }
        .card-desc { color: var(--text-muted); font-size: 13px; margin-bottom: 20px; padding-left: 48px; }

        /* ═══ Buttons ═══ */
        .btn {
            padding: 8px 16px; border: none; border-radius: 8px; cursor: pointer;
            font-weight: 600; font-size: 13px; font-family: 'Inter', sans-serif;
            transition: transform 0.2s, box-shadow 0.3s; white-space: nowrap;
        }
        .btn:hover { transform: translateY(-1px); }
        .btn-danger  { background: linear-gradient(135deg, #ff4757, #c0392b); color: white; }
        .btn-danger:hover  { box-shadow: 0 4px 14px rgba(255,71,87,0.4); }
        .btn-restore { background: linear-gradient(135deg, var(--blue), #2980b9); color: white; }
        .btn-restore:hover { box-shadow: 0 4px 14px rgba(52,152,219,0.4); }
        .btn-primary { background: linear-gradient(135deg, var(--primary), var(--primary-hover)); color: white; }
        .btn-primary:hover { box-shadow: 0 4px 14px rgba(111,66,193,0.4); }

        /* ═══ Delete / Restore two-column grid ═══ */
        .dr-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
        }
        .dr-panel {
            background: rgba(15, 23, 42, 0.5);
            border: 1px solid var(--glass);
            border-radius: 12px;
            overflow: hidden;
        }
        .dr-panel-title {
            font-size: 12px; font-weight: 700; text-transform: uppercase;
            letter-spacing: 0.8px; color: var(--text-muted);
            padding: 10px 14px; border-bottom: 1px solid var(--glass);
            background: rgba(255,255,255,0.02);
        }
        .dr-list {
            max-height: 210px;
            overflow-y: auto;
        }
        .dr-list::-webkit-scrollbar { width: 4px; }
        .dr-list::-webkit-scrollbar-thumb { background: rgba(111,66,193,0.3); border-radius: 2px; }
        .dr-row {
            display: flex; align-items: center; justify-content: space-between;
            gap: 10px; padding: 9px 14px;
            border-bottom: 1px solid rgba(255,255,255,0.04);
            transition: background 0.2s;
        }
        .dr-row:last-child { border-bottom: none; }
        .dr-row:hover { background: rgba(255,255,255,0.03); }
        .dr-info { flex: 1; min-width: 0; }
        .dr-sender { font-size: 12px; font-weight: 600; color: white; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .dr-subject { font-size: 11px; color: var(--text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .dr-row form { flex-shrink: 0; margin: 0; }
        .dr-empty { padding: 20px; text-align: center; color: var(--text-muted); font-size: 13px; }

        /* ═══ Security Scanner ═══ */
        .scan-summary {
            display: inline-flex; align-items: center; gap: 6px;
            background: rgba(255,71,87,0.1); border: 1px solid rgba(255,71,87,0.3);
            color: #fca5a5; padding: 4px 12px; border-radius: 20px;
            font-size: 12px; font-weight: 700; margin-bottom: 16px;
        }
        .scan-summary.clean {
            background: rgba(46,204,113,0.1); border-color: rgba(46,204,113,0.3); color: var(--green);
        }
        .scan-table { width: 100%; border-collapse: collapse; }
        .scan-table tr { border-bottom: 1px solid rgba(255,255,255,0.05); transition: background 0.2s; }
        .scan-table tr:last-child { border-bottom: none; }
        .scan-table tr:hover { background: rgba(255,255,255,0.02); }
        .scan-table td { padding: 10px 12px; font-size: 13px; vertical-align: middle; }
        .badge {
            display: inline-block; padding: 3px 9px; border-radius: 12px;
            font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;
            white-space: nowrap;
        }
        .badge-otp       { background: rgba(243,156,18,0.15); color: var(--amber); border: 1px solid rgba(243,156,18,0.3); }
        .badge-sensitive { background: rgba(255,71,87,0.18); color: #ff6b7a; border: 1px solid rgba(255,71,87,0.45);
                           box-shadow: 0 0 6px rgba(255,71,87,0.25); }
        .badge-active    { background: rgba(46,204,113,0.15); color: #2ecc71; border: 1px solid rgba(46,204,113,0.35);
                           box-shadow: 0 0 6px rgba(46,204,113,0.2); font-variant-numeric: tabular-nums; }
        .badge-expired   { background: rgba(148,163,184,0.1); color: var(--text-muted); border: 1px solid rgba(148,163,184,0.2); }
        .badge-resolved  { background: rgba(148,163,184,0.1); color: var(--text-muted); border: 1px solid rgba(148,163,184,0.2); }
        .badge-resolved-status { background: rgba(46,204,113,0.1); color: #2ecc71; border: 1px solid rgba(46,204,113,0.25); }
        .scan-value  { font-weight: 700; color: white; letter-spacing: 1px; }
        .scan-sender { color: var(--text-muted); font-size: 12px; }
        .scan-ts     { color: var(--text-muted); font-size: 11px; white-space: nowrap; }
        .row-sensitive td { background: rgba(255,71,87,0.04); }
        .action-cell { white-space: nowrap; }
        .action-link {
            display: inline-block; font-size: 11px; font-weight: 600; padding: 4px 10px;
            border-radius: 6px; cursor: pointer; text-decoration: none; transition: 0.2s;
            border: 1px solid rgba(255,255,255,0.12); color: var(--text-muted);
            background: transparent; margin-right: 4px;
        }
        .action-link:hover { border-color: var(--primary); color: var(--primary); }
        .investigate-link { color: #94a3b8; }
        .investigate-link:hover { color: #6f42c1; border-color: #6f42c1; }
        .mark-safe-btn { color: #2ecc71; border-color: rgba(46,204,113,0.3); }
        .mark-safe-btn:hover { background: rgba(46,204,113,0.1); border-color: #2ecc71; }
        .empty-state { color: var(--text-muted); text-align: center; padding: 24px; font-size: 13px; }

        /* ═══ Click-to-Copy OTP Pill ═══ */
        .otp-copy-pill {
            display: inline-flex; align-items: center; gap: 6px;
            background: rgba(243,156,18,0.15); border: 1px solid rgba(243,156,18,0.4);
            color: var(--amber); padding: 4px 12px; border-radius: 8px;
            cursor: pointer; user-select: none;
            transition: background 0.2s, border-color 0.2s, transform 0.15s;
        }
        .otp-copy-pill:hover { background: rgba(243,156,18,0.28); border-color: rgba(243,156,18,0.7); transform: translateY(-1px); }
        .otp-copy-pill.copied { background: rgba(46,204,113,0.18); border-color: rgba(46,204,113,0.5); color: #2ecc71; }
        .otp-code-text { font-weight: 700; letter-spacing: 2px; }
        .otp-copy-icon { font-size: 11px; opacity: 0.55; }
        .otp-copy-pill.copied .otp-copy-icon { display: none; }
    </style>
</head>
<body>

    <!-- SIDEBAR -->
    <div class="sidebar">
        <div class="logo">MasterMail.ai</div>
        <a href="emails"  class="nav-link">📥 Inbox</a>
        <a href="replies" class="nav-link">💬 Replies</a>
        <a href="buckets" class="nav-link">🏷️ Buckets</a>
        <a href="advanced" class="nav-link active">🛡️ Security Lab</a>
        <%
            com.mastermail.model.User sidebarUser = (com.mastermail.model.User) session.getAttribute("user");
            if (sidebarUser != null && sidebarUser.isAdmin()) {
        %>
            <a href="admin" class="nav-link">⚙️ Admin</a>
        <% } %>
        <div style="margin-top: auto;">
            <a href="logout" class="nav-link">🚪 Logout</a>
        </div>
    </div>

    <!-- MAIN CONTENT -->
    <div class="main-content">
        <div class="page-title">🛡️ Security Lab</div>

        <%
            List<Email> inbox = (List<Email>) request.getAttribute("inboxEmails");
            List<Email> trash = (List<Email>) request.getAttribute("trashEmails");
            @SuppressWarnings("unchecked")
            List<String[]> otps = (List<String[]>) request.getAttribute("otpList");
            if (inbox == null) inbox = new ArrayList<>();
            if (trash == null) trash = new ArrayList<>();
            if (otps  == null) otps  = new ArrayList<>();
        %>

        <!-- ══════════════════════════════════ -->
        <!-- CARD 1: SAFE DELETE & RESTORE      -->
        <!-- ══════════════════════════════════ -->
        <div class="glass-card">
            <div class="card-header">
                <span class="card-icon red">🗑️</span>
                <h3>Safe Delete &amp; Restore</h3>
            </div>
            <p class="card-desc">Delete emails to trash or restore them back to your inbox. Deletes are always reversible.</p>

            <div class="dr-grid">
                <!-- Inbox → delete -->
                <div class="dr-panel">
                    <div class="dr-panel-title">📥 Inbox &nbsp;<span style="color:white;font-size:12px;">(<%= inbox.size() %>)</span></div>
                    <div class="dr-list">
                        <% if (inbox.isEmpty()) { %>
                            <div class="dr-empty">Inbox is empty</div>
                        <% } else { for (Email e : inbox) { %>
                            <div class="dr-row">
                                <div class="dr-info">
                                    <div class="dr-sender"><%= esc(trunc(e.getSender(), 32)) %></div>
                                    <div class="dr-subject"><%= esc(trunc(e.getSubject(), 44)) %></div>
                                </div>
                                <form action="advanced" method="post">
                                    <input type="hidden" name="action" value="safeDelete">
                                    <input type="hidden" name="emailId" value="<%= e.getId() %>">
                                    <button type="submit" class="btn btn-danger" style="padding:5px 11px;font-size:12px;">🗑 Del</button>
                                </form>
                            </div>
                        <% } } %>
                    </div>
                </div>

                <!-- Trash → restore -->
                <div class="dr-panel">
                    <div class="dr-panel-title">🗑️ Trash &nbsp;<span style="color:white;font-size:12px;">(<%= trash.size() %>)</span></div>
                    <div class="dr-list">
                        <% if (trash.isEmpty()) { %>
                            <div class="dr-empty">Trash is empty</div>
                        <% } else { for (Email e : trash) { %>
                            <div class="dr-row">
                                <div class="dr-info">
                                    <div class="dr-sender"><%= esc(trunc(e.getSender(), 32)) %></div>
                                    <div class="dr-subject"><%= esc(trunc(e.getSubject(), 44)) %></div>
                                </div>
                                <form action="advanced" method="post">
                                    <input type="hidden" name="action" value="restore">
                                    <input type="hidden" name="emailId" value="<%= e.getId() %>">
                                    <button type="submit" class="btn btn-restore" style="padding:5px 11px;font-size:12px;">↩ Restore</button>
                                </form>
                            </div>
                        <% } } %>
                    </div>
                </div>
            </div>
        </div>

        <!-- ══════════════════════════════════ -->
        <!-- CARD 3: SECURITY SCANNER           -->
        <!-- ══════════════════════════════════ -->
        <div class="glass-card">
            <div class="card-header">
                <span class="card-icon amber">🔒</span>
                <h3>Security Scanner — OTPs &amp; Keywords</h3>
            </div>
            <p class="card-desc">Scans your inbox for sensitive security codes, passwords, and credential keywords.</p>

            <% if (otps.isEmpty()) { %>
                <div class="scan-summary clean">✅ No findings — inbox is clean</div>
                <div class="empty-state">No active OTP codes or sensitive keywords detected in your emails.</div>
            <% } else { %>
                <div class="scan-summary">⚠ <%= otps.size() %> unique finding<%= otps.size() > 1 ? "s" : "" %> detected</div>
                <table class="scan-table">
                    <thead>
                        <tr style="border-bottom:1px solid rgba(255,255,255,0.08);">
                            <th style="padding:8px 12px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.6px;color:var(--text-muted);text-align:left;width:110px;">Type</th>
                            <th style="padding:8px 12px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.6px;color:var(--text-muted);text-align:left;">Value</th>
                            <th style="padding:8px 12px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.6px;color:var(--text-muted);text-align:left;">Source</th>
                            <th style="padding:8px 12px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.6px;color:var(--text-muted);text-align:left;">Detected</th>
                            <th style="padding:8px 12px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.6px;color:var(--text-muted);text-align:left;">Status</th>
                            <th style="padding:8px 12px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.6px;color:var(--text-muted);text-align:left;">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                    <% for (String[] finding : otps) {
                        // finding[0]=type  [1]=value  [2]=sender  [3]=timestamp  [4]=ageStatus
                        // [5]=epochMs  [6]=emailId  [7]=findingKey  [8]=isResolved
                        boolean isOtp = "otp".equals(finding[0]);
                        boolean isSensitive = "sensitive".equals(finding[0]);
                        boolean isResolved = "true".equals(finding.length > 8 ? finding[8] : "false");
                        String emailId = finding.length > 6 ? finding[6] : "0";
                        String findingKey = finding.length > 7 ? finding[7] : "";
                        String rowClass = (isSensitive && !isResolved) ? "row-sensitive" : "";
                    %>
                    <tr class="<%= rowClass %>">
                        <td>
                            <% if (isResolved && isSensitive) { %>
                                <span class="badge badge-resolved">✔ Sensitive</span>
                            <% } else { %>
                                <span class="badge <%= isOtp ? "badge-otp" : "badge-sensitive" %>">
                                    <%= isOtp ? "🔑 OTP Code" : "⚠ Sensitive" %>
                                </span>
                            <% } %>
                        </td>
                        <td>
                            <% if (isOtp) { %>
                                <span class="otp-copy-pill" onclick="copyOtp(this)" data-otp-code="<%= esc(finding[1]) %>">
                                    <span class="otp-code-text"><%= esc(finding[1]) %></span>
                                    <span class="otp-copy-icon">📋</span>
                                </span>
                            <% } else { %>
                                <span class="scan-value"><%= esc(finding[1]) %></span>
                            <% } %>
                        </td>
                        <td><span class="scan-sender">from <%= esc(finding[2]) %></span></td>
                        <td><span class="scan-ts"><%= esc(finding[3]) %></span></td>
                        <td>
                            <% if (isOtp && finding[4] != null && !finding[4].isEmpty()) {
                                boolean isActive = "active".equals(finding[4]);
                                String epochMs = finding[5];
                            %>
                                <span class="badge <%= isActive ? "badge-active" : "badge-expired" %>"
                                      <%= isActive ? "data-detected-ms=\"" + esc(epochMs) + "\"" : "" %>>
                                    <%= isActive ? "● Active" : "○ Expired" %>
                                </span>
                            <% } else if (isResolved) { %>
                                <span class="badge badge-resolved-status">✔ Resolved</span>
                            <% } %>
                        </td>
                        <td class="action-cell">
                            <% if (!"0".equals(emailId)) { %>
                                <a href="emails?highlight=<%= emailId %>" class="action-link investigate-link" title="Open in Inbox">↗ View</a>
                            <% } %>
                            <% if (isSensitive && !isResolved) { %>
                                <button class="action-link mark-safe-btn"
                                        data-finding-key="<%= esc(findingKey) %>"
                                        onclick="markSafe(this)" title="Mark as reviewed and safe">✔ Mark Safe</button>
                            <% } %>
                        </td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
            <% } %>
        </div>

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

        function initCountdowns() {
            document.querySelectorAll('.badge-active[data-detected-ms]').forEach(function(badge) {
                var detectedMs = parseInt(badge.getAttribute('data-detected-ms'), 10);
                if (!detectedMs) return;
                var expireAt = detectedMs + 15 * 60 * 1000;

                function tick() {
                    var remaining = expireAt - Date.now();
                    if (remaining <= 0) {
                        badge.textContent = '○ Expired';
                        badge.classList.remove('badge-active');
                        badge.classList.add('badge-expired');
                        clearInterval(badge._timer);
                        return;
                    }
                    var mins = Math.floor(remaining / 60000);
                    var secs = Math.floor((remaining % 60000) / 1000);
                    badge.textContent = '● Active (' +
                        String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0') + ')';
                }
                tick();
                badge._timer = setInterval(tick, 1000);
            });
        }

        document.addEventListener('DOMContentLoaded', initCountdowns);

        function markSafe(btn) {
            var findingKey = btn.getAttribute('data-finding-key');
            if (!findingKey) return;
            fetch('resolve-alert', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'findingKey=' + encodeURIComponent(findingKey)
            }).then(function(resp) {
                if (resp.ok) {
                    var row = btn.closest('tr');
                    // Swap SENSITIVE badge to resolved
                    var typeBadge = row.querySelector('.badge-sensitive');
                    if (typeBadge) {
                        typeBadge.textContent = '✔ Sensitive';
                        typeBadge.className = 'badge badge-resolved';
                    }
                    // Swap status cell to resolved
                    var statusCell = row.cells[4];
                    statusCell.innerHTML = '<span class="badge badge-resolved-status">✔ Resolved</span>';
                    // Remove the red row highlight and the action buttons
                    row.classList.remove('row-sensitive');
                    row.querySelectorAll('td').forEach(function(td) {
                        td.style.background = '';
                    });
                    var actionCell = row.cells[5];
                    var markSafeBtn = actionCell.querySelector('.mark-safe-btn');
                    if (markSafeBtn) markSafeBtn.remove();
                }
            });
        }
    </script>

</body>
</html>
