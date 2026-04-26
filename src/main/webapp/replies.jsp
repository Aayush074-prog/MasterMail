<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.mastermail.model.*, java.util.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;").replace("'","&#39;");
    }
    private String extractEmail(String sender) {
        if (sender == null) return "";
        int s = sender.indexOf('<');
        int e = sender.indexOf('>');
        if (s >= 0 && e > s) return sender.substring(s + 1, e).trim();
        if (sender.contains("@")) return sender.trim();
        return "";
    }
    private String truncate(String s, int max) {
        if (s == null) return "";
        return s.length() > max ? s.substring(0, max) + "..." : s;
    }
%>
<html>
<head>
    <title>MasterMail - Replies</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --glass: rgba(255, 255, 255, 0.05);
            --primary: #6f42c1;
            --primary-hover: #8559da;
            --bg: #0f172a;
            --text-muted: #94a3b8;
            --col-sent: #6f42c1;
            --col-received: #3498db;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: var(--bg); color: white;
            font-family: 'Inter', sans-serif;
            display: flex; height: 100vh; overflow: hidden;
        }

        /* ═══ Sidebar ═══ */
        .sidebar {
            width: 260px; background: #1e293b; padding: 30px 20px;
            border-right: 1px solid var(--glass);
            display: flex; flex-direction: column;
        }
        .logo { font-size: 24px; font-weight: 700; color: var(--primary); margin-bottom: 40px; padding-left: 10px; }
        .nav-link {
            color: var(--text-muted); text-decoration: none; padding: 12px 15px;
            border-radius: 8px; margin-bottom: 5px; transition: 0.3s;
            display: flex; align-items: center;
        }
        .nav-link:hover, .nav-link.active { background: var(--glass); color: white; }

        /* ═══ Main Area ═══ */
        .main-area {
            flex: 1; display: flex; overflow: hidden;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
        }

        /* ═══ Thread List (Left Panel) ═══ */
        .thread-list {
            width: 360px; border-right: 1px solid var(--glass);
            overflow-y: auto; padding: 20px;
        }
        .thread-list h3 {
            font-size: 18px; font-weight: 700; margin-bottom: 16px;
            padding-bottom: 12px; border-bottom: 1px solid var(--glass);
        }

        /* ═══ Auto-Drafts Section ═══ */
        .draft-section {
            background: rgba(46, 204, 113, 0.08); border: 1px solid rgba(46, 204, 113, 0.3);
            border-radius: 12px; padding: 16px; margin-bottom: 20px;
        }
        .draft-section h4 {
            font-size: 14px; font-weight: 700; color: #2ecc71;
            text-transform: uppercase; letter-spacing: 1px; margin-bottom: 12px;
        }
        .draft-card {
            background: rgba(15, 23, 42, 0.7); border: 1px solid rgba(46, 204, 113, 0.2);
            border-radius: 10px; padding: 14px; margin-bottom: 10px;
        }
        .draft-card .draft-to {
            font-size: 13px; font-weight: 600; color: white; margin-bottom: 4px;
        }
        .draft-card .draft-msg {
            font-size: 12px; color: var(--text-muted); margin-bottom: 10px;
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        }
        .draft-card .draft-actions {
            display: flex; gap: 8px;
        }
        .approve-btn {
            flex: 1; background: linear-gradient(135deg, #2ecc71, #27ae60);
            color: white; border: none; padding: 8px 12px; border-radius: 8px;
            cursor: pointer; font-weight: 600; font-size: 12px; transition: 0.3s;
        }
        .approve-btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(46,204,113,0.4); }
        .discard-btn {
            background: transparent; border: 1px solid rgba(239,68,68,0.3);
            color: #ef4444; padding: 8px 12px; border-radius: 8px;
            cursor: pointer; font-size: 12px; transition: 0.3s;
        }
        .discard-btn:hover { background: rgba(239,68,68,0.1); border-color: #ef4444; }
        .draft-badge {
            background: rgba(46,204,113,0.2); color: #2ecc71;
            padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 700;
        }

        .thread-card {
            background: rgba(30, 41, 59, 0.55); backdrop-filter: blur(15px);
            border: 1px solid var(--glass); border-radius: 14px;
            padding: 16px; margin-bottom: 10px; cursor: pointer;
            transition: all 0.3s ease; text-decoration: none; display: block; color: white;
        }
        .thread-card:hover { border-color: var(--primary); transform: translateX(4px); box-shadow: 0 5px 15px rgba(0,0,0,0.2); }
        .thread-card.active { border-color: var(--primary); background: rgba(111,66,193,0.1); }

        .thread-card .tc-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
        .thread-card .tc-name { font-weight: 600; font-size: 14px; }
        .thread-card .tc-time { color: var(--text-muted); font-size: 11px; }
        .thread-card .tc-subject { font-size: 13px; color: #cbd5e1; margin-bottom: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .thread-card .tc-preview { font-size: 12px; color: var(--text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .thread-card .tc-count {
            display: inline-block; background: rgba(111,66,193,0.2); color: var(--primary);
            padding: 2px 8px; border-radius: 12px; font-size: 10px; font-weight: 700;
        }

        /* ═══ Auto-Reply Rules Section ═══ */
        .rules-section {
            background: rgba(111, 66, 193, 0.06);
            border: 1px solid rgba(111, 66, 193, 0.25);
            border-radius: 12px; padding: 14px; margin-bottom: 16px;
        }
        .rules-section .rules-title {
            font-size: 12px; font-weight: 700; color: var(--primary);
            text-transform: uppercase; letter-spacing: 1px;
            display: flex; justify-content: space-between; align-items: center;
            margin-bottom: 10px;
        }
        .add-rule-toggle {
            background: transparent; border: 1px solid rgba(111,66,193,0.4);
            color: var(--primary); padding: 3px 9px; border-radius: 6px;
            cursor: pointer; font-size: 11px; font-family: 'Inter', sans-serif; transition: 0.3s;
        }
        .add-rule-toggle:hover { background: rgba(111,66,193,0.12); }
        .rule-form {
            display: none; flex-direction: column; gap: 7px; margin-bottom: 10px;
        }
        .rule-form input {
            background: rgba(15, 23, 42, 0.7); border: 1px solid var(--glass);
            color: white; padding: 9px 12px; border-radius: 8px;
            font-size: 13px; font-family: 'Inter', sans-serif; outline: none;
            transition: border-color 0.3s; width: 100%;
        }
        .rule-form input:focus { border-color: var(--primary); }
        .rule-form input::placeholder { color: #475569; }
        .save-rule-btn {
            background: linear-gradient(135deg, var(--primary), var(--primary-hover));
            color: white; border: none; padding: 9px; border-radius: 8px;
            cursor: pointer; font-weight: 600; font-size: 13px;
            font-family: 'Inter', sans-serif; transition: 0.3s;
        }
        .save-rule-btn:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(111,66,193,0.35); }
        .rule-item {
            display: flex; justify-content: space-between; align-items: center;
            padding: 9px 10px; background: rgba(15, 23, 42, 0.5); border-radius: 8px;
            margin-bottom: 6px; border-left: 3px solid var(--primary);
        }
        .rule-item.inactive { border-left-color: #475569; }
        .rule-item .rule-text { font-size: 12px; color: white; flex: 1; min-width: 0; }
        .rule-item .rule-text .rule-keyword { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .rule-item .rule-text small { color: var(--text-muted); display: block; margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .rule-btns { display: flex; gap: 4px; flex-shrink: 0; margin-left: 6px; }
        .rule-btn {
            background: transparent; padding: 4px 7px; border-radius: 5px;
            cursor: pointer; font-size: 11px; font-family: 'Inter', sans-serif; transition: 0.3s;
        }
        .rule-toggle { border: 1px solid rgba(255,255,255,0.12); color: var(--text-muted); }
        .rule-toggle:hover { border-color: var(--primary); color: var(--primary); }
        .rule-delete { border: 1px solid rgba(239,68,68,0.3); color: #ef4444; }
        .rule-delete:hover { background: rgba(239,68,68,0.1); }

        .empty-threads { text-align: center; padding: 60px 20px; color: var(--text-muted); }
        .empty-threads .emoji { font-size: 48px; margin-bottom: 12px; }

        /* ═══ Conversation Panel (Right) ═══ */
        .convo-panel {
            flex: 1; display: flex; flex-direction: column; overflow: hidden;
        }
        .convo-header {
            padding: 20px 24px; border-bottom: 1px solid var(--glass);
            display: flex; justify-content: space-between; align-items: center;
        }
        .convo-header h3 { font-size: 16px; font-weight: 600; }
        .convo-header .ch-email { color: var(--text-muted); font-size: 12px; margin-top: 2px; }

        .convo-messages {
            flex: 1; overflow-y: auto; padding: 24px;
            display: flex; flex-direction: column; gap: 12px;
        }
        .convo-messages::-webkit-scrollbar { width: 6px; }
        .convo-messages::-webkit-scrollbar-track { background: transparent; }
        .convo-messages::-webkit-scrollbar-thumb { background: rgba(111,66,193,0.3); border-radius: 3px; }

        /* Chat bubbles */
        .msg-bubble {
            max-width: 75%; padding: 14px 18px; border-radius: 16px;
            font-size: 14px; line-height: 1.6; word-wrap: break-word;
            white-space: pre-wrap; animation: fadeIn 0.3s ease;
        }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }

        .msg-received {
            align-self: flex-start;
            background: rgba(52, 152, 219, 0.12); border: 1px solid rgba(52,152,219,0.2);
            border-bottom-left-radius: 4px;
        }
        .msg-sent {
            align-self: flex-end;
            background: rgba(111, 66, 193, 0.15); border: 1px solid rgba(111,66,193,0.25);
            border-bottom-right-radius: 4px;
        }
        .msg-meta {
            font-size: 11px; color: var(--text-muted); margin-top: 6px;
            display: flex; justify-content: space-between; align-items: center;
        }
        .msg-sender-tag {
            font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;
            padding: 2px 8px; border-radius: 10px; margin-bottom: 6px; display: inline-block;
        }
        .msg-sender-tag.sent { background: rgba(111,66,193,0.2); color: #8559da; }
        .msg-sender-tag.received { background: rgba(52,152,219,0.2); color: #3498db; }

        /* ═══ Reply Compose Box ═══ */
        .compose-box {
            border-top: 1px solid var(--glass); padding: 16px 24px;
            background: rgba(15, 23, 42, 0.5);
        }
        .compose-box form { display: flex; gap: 10px; align-items: flex-end; }
        .compose-textarea {
            flex: 1; min-height: 50px; max-height: 120px;
            background: rgba(15,23,42,0.7); border: 1px solid var(--glass);
            color: white; padding: 12px 16px; border-radius: 12px;
            font-size: 14px; font-family: 'Inter', sans-serif;
            resize: none; outline: none; transition: border-color 0.3s;
        }
        .compose-textarea:focus { border-color: var(--primary); }
        .compose-send {
            background: linear-gradient(135deg, #2ecc71, #27ae60);
            color: white; border: none; padding: 12px 20px; border-radius: 12px;
            cursor: pointer; font-weight: 600; font-size: 14px;
            font-family: 'Inter', sans-serif; transition: 0.3s;
            white-space: nowrap;
        }
        .compose-send:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(46,204,113,0.35); }

        .empty-convo {
            flex: 1; display: flex; align-items: center; justify-content: center;
            color: var(--text-muted); font-size: 15px; text-align: center;
        }
        .empty-convo .emoji { font-size: 56px; margin-bottom: 15px; }
    </style>
</head>
<body>
    <%
        User currentUser = (User) session.getAttribute("user");
        List<String[]> threads = (List<String[]>) request.getAttribute("replyThreads");
        List<String[]> conversation = (List<String[]>) request.getAttribute("conversation");
        List<String[]> autoDrafts = (List<String[]>) request.getAttribute("autoDrafts");
        String threadEmail = (String) request.getAttribute("threadEmail");
        String threadName = (String) request.getAttribute("threadName");
        if (threads == null) threads = new java.util.ArrayList<>();
        if (autoDrafts == null) autoDrafts = new java.util.ArrayList<>();
    %>

    <div class="sidebar">
        <div class="logo">MasterMail.ai</div>
        <a href="emails" class="nav-link">📥 Inbox</a>
        <a href="replies" class="nav-link active">💬 Replies</a>
        <a href="buckets" class="nav-link">🏷️ Buckets</a>
        <a href="advanced" class="nav-link">🛡️ Security Lab</a>
        <%
            if (currentUser != null && currentUser.isAdmin()) {
        %>
            <a href="admin" class="nav-link">⚙️ Admin</a>
        <% } %>
        <div style="margin-top: auto;">
            <a href="logout" class="nav-link">🚪 Logout</a>
        </div>
    </div>

    <div class="main-area">
        <%-- ═══ Thread List (Left) ═══ --%>
        <div class="thread-list">
            <%-- ═══ Auto-Reply Rules Management ═══ --%>
            <%
                List<String[]> autoRules = (List<String[]>) request.getAttribute("autoReplyRules");
                if (autoRules == null) autoRules = new java.util.ArrayList<>();
            %>
            <div class="rules-section">
                <div class="rules-title">
                    🤖 Auto-Reply Rules
                    <button type="button" class="add-rule-toggle" onclick="
                        var f=document.getElementById('rule-form');
                        f.style.display = f.style.display==='flex' ? 'none' : 'flex';">
                        + Add Rule
                    </button>
                </div>
                <form id="rule-form" class="rule-form" action="auto-reply" method="post">
                    <input type="hidden" name="action" value="addRule">
                    <input type="text" name="keyword" placeholder="Keyword trigger (e.g. happy birthday)" required>
                    <input type="text" name="replyMessage" placeholder="Reply message (e.g. Thank you!)" required>
                    <button type="submit" class="save-rule-btn">💾 Save Rule</button>
                </form>
                <% if (autoRules.isEmpty()) { %>
                    <div style="text-align: center; padding: 10px 0 4px; color: var(--text-muted); font-size: 12px;">
                        No rules yet — click "+ Add Rule" to create one.
                    </div>
                <% } else {
                    for (String[] rule : autoRules) {
                        boolean ruleActive = Boolean.parseBoolean(rule[3]);
                %>
                    <div class="rule-item <%= ruleActive ? "" : "inactive" %>">
                        <div class="rule-text">
                            <div class="rule-keyword">"<%= esc(rule[1]) %>"</div>
                            <small>→ "<%= esc(rule[2]) %>"  &nbsp;·&nbsp;  <%= ruleActive ? "✅ Active" : "⏸ Paused" %></small>
                        </div>
                        <div class="rule-btns">
                            <form action="auto-reply" method="post" style="margin:0;">
                                <input type="hidden" name="action" value="toggleRule">
                                <input type="hidden" name="ruleId" value="<%= rule[0] %>">
                                <button type="submit" class="rule-btn rule-toggle"><%= ruleActive ? "⏸" : "▶" %></button>
                            </form>
                            <form action="auto-reply" method="post" style="margin:0;">
                                <input type="hidden" name="action" value="deleteRule">
                                <input type="hidden" name="ruleId" value="<%= rule[0] %>">
                                <button type="submit" class="rule-btn rule-delete">🗑</button>
                            </form>
                        </div>
                    </div>
                <% } } %>
            </div>

            <%-- ═══ Auto-Drafted Replies (Awaiting Approval) ═══ --%>
            <% if (!autoDrafts.isEmpty()) { %>
                <div class="draft-section">
                    <h4>🤖 Auto-Drafts Awaiting Approval (<%= autoDrafts.size() %>)</h4>
                    <%
                        for (String[] draft : autoDrafts) {
                            // draft = [draft_id, email_id, recipient_email, recipient_name, subject, draft_message, created_at]
                            String draftId = draft[0];
                            String recipientEmail = draft[2];
                            String recipientName = draft[3];
                            String subject = draft[4];
                            String message = draft[5];
                            String createdAt = draft[6];
                    %>
                        <div class="draft-card">
                            <div class="draft-to">To: <%= esc(recipientName != null && !recipientName.isEmpty() ? recipientName : recipientEmail) %></div>
                            <div class="draft-msg">"<%= esc(message) %>"</div>
                            <div class="draft-actions">
                                <form action="replies" method="post" style="flex: 1; margin: 0;">
                                    <input type="hidden" name="action" value="approveDraft">
                                    <input type="hidden" name="draftId" value="<%= draftId %>">
                                    <input type="hidden" name="recipient" value="<%= esc(recipientEmail) %>">
                                    <input type="hidden" name="subject" value="<%= esc(subject) %>">
                                    <input type="hidden" name="finalMessage" value="<%= esc(message) %>">
                                    <button type="submit" class="approve-btn">✅ Approve & Send</button>
                                </form>
                                <form action="replies" method="post" style="margin: 0;">
                                    <input type="hidden" name="action" value="deleteDraft">
                                    <input type="hidden" name="draftId" value="<%= draftId %>">
                                    <button type="submit" class="discard-btn">🗑️</button>
                                </form>
                            </div>
                        </div>
                    <% } %>
                </div>
            <% } %>

            <h3>💬 Conversations</h3>

            <% if (threads.isEmpty()) { %>
                <div class="empty-threads">
                    <div class="emoji">📭</div>
                    <p>No replies yet.<br>Send a reply from your inbox to start a conversation.</p>
                </div>
            <% } else {
                for (String[] t : threads) {
                    // t = [recipientEmail, recipientName, subject, message, sentAt, msgCount]
                    boolean isActive = t[0].equals(threadEmail);
            %>
                <a href="replies?thread=<%= java.net.URLEncoder.encode(t[0], "UTF-8") %>"
                   class="thread-card <%= isActive ? "active" : "" %>">
                    <div class="tc-header">
                        <span class="tc-name"><%= esc(t[1] != null && !t[1].isEmpty() ? t[1] : t[0]) %></span>
                        <span class="tc-time"><%= t[4] %></span>
                    </div>
                    <div class="tc-subject"><%= esc(t[2]) %></div>
                    <div class="tc-preview"><%= truncate(t[3], 60) %></div>
                    <span class="tc-count"><%= t[5] %> message(s)</span>
                </a>
            <% } } %>
        </div>

        <%-- ═══ Conversation Panel (Right) ═══ --%>
        <div class="convo-panel">
            <% if (threadEmail != null && conversation != null) { %>

                <div class="convo-header">
                    <div>
                        <h3><%= esc(threadName != null ? threadName : threadEmail) %></h3>
                        <div class="ch-email"><%= esc(threadEmail) %></div>
                    </div>
                    <a href="emails" style="color: var(--text-muted); text-decoration: none; font-size: 13px;">← Back to Inbox</a>
                </div>

                <div class="convo-messages" id="convoMessages">
                    <% if (conversation.isEmpty()) { %>
                        <div style="text-align: center; color: var(--text-muted); padding: 40px;">
                            No messages found in this conversation yet.
                        </div>
                    <% } else {
                        for (String[] msg : conversation) {
                            // msg = [type, timestamp, subject, body, senderName]
                            boolean isSent = "sent".equals(msg[0]);
                    %>
                        <div class="msg-bubble <%= isSent ? "msg-sent" : "msg-received" %>">
                            <div class="msg-sender-tag <%= isSent ? "sent" : "received" %>">
                                <%= isSent ? "You" : esc(msg[4]) %>
                            </div>
                            <div><%= esc(msg[3]) %></div>
                            <div class="msg-meta">
                                <span><%= msg[2] != null ? esc(msg[2]) : "" %></span>
                                <span><%= msg[1] %></span>
                            </div>
                        </div>
                    <% } } %>
                </div>

                <%-- ═══ Compose Reply ═══ --%>
                <div class="compose-box">
                    <form action="send-reply" method="post">
                        <input type="hidden" name="recipient" value="<%= esc(threadEmail) %>">
                        <input type="hidden" name="subject" value="<%= esc(conversation != null && !conversation.isEmpty() ? conversation.get(conversation.size()-1)[2] : "") %>">
                        <textarea class="compose-textarea" name="finalMessage"
                                  placeholder="Type a message..." required></textarea>
                        <button type="submit" class="compose-send">📤 Send</button>
                    </form>
                </div>

            <% } else { %>
                <div class="empty-convo">
                    <div>
                        <div class="emoji">💬</div>
                        <p>Select a conversation to view the thread<br>
                           <span style="font-size: 13px; color: var(--text-muted);">or reply to an email from your inbox to start one</span>
                        </p>
                    </div>
                </div>
            <% } %>
        </div>
    </div>

    <script>
        // Auto-scroll to bottom of conversation
        var convo = document.getElementById('convoMessages');
        if (convo) { convo.scrollTop = convo.scrollHeight; }
    </script>
</body>
</html>

