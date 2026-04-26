<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%!
    private String escAttr(String s) {
        if (s == null) return "";
        return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;").replace("'","&#39;");
    }
%>
<html>
<head>
    <title>MasterMail — Approve Reply</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --glass: rgba(255, 255, 255, 0.05);
            --primary: #6f42c1;
            --primary-hover: #8559da;
            --bg: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.55);
            --text-muted: #94a3b8;
            --glow-work: #2ecc71;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            background: linear-gradient(135deg, #0f172a 0%, #1a1a2e 40%, #16213e 100%);
            color: white;
            font-family: 'Inter', sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 40px 20px;
        }

        body::before {
            content: '';
            position: fixed;
            width: 350px; height: 350px;
            border-radius: 50%;
            background: var(--primary);
            filter: blur(80px);
            opacity: 0.12;
            top: -80px; right: -80px;
            z-index: 0;
            animation: floatOrb 8s ease-in-out infinite alternate;
        }

        @keyframes floatOrb {
            0% { transform: translate(0, 0) scale(1); }
            100% { transform: translate(30px, 20px) scale(1.1); }
        }

        .glass-card {
            position: relative;
            z-index: 1;
            background: var(--card-bg);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid var(--glass);
            border-radius: 20px;
            padding: 35px;
            max-width: 560px;
            width: 100%;
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.3);
        }

        .card-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
        }
        .card-header .icon {
            width: 40px; height: 40px;
            border-radius: 12px;
            background: rgba(111, 66, 193, 0.15);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        }
        .card-header h2 {
            font-size: 22px;
            font-weight: 600;
            background: linear-gradient(135deg, var(--primary), var(--primary-hover));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .recipient {
            color: var(--text-muted);
            font-size: 14px;
            margin-bottom: 20px;
        }
        .recipient strong {
            color: white;
        }

        .divider {
            border: none;
            border-top: 1px solid var(--glass);
            margin: 20px 0;
        }

        label {
            display: block;
            font-size: 12px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
        }

        textarea {
            width: 100%;
            height: 160px;
            background: rgba(15, 23, 42, 0.7);
            border: 1px solid var(--glass);
            color: white;
            padding: 16px;
            border-radius: 12px;
            font-size: 15px;
            font-family: 'Inter', sans-serif;
            line-height: 1.6;
            resize: vertical;
            outline: none;
            transition: border-color 0.3s, box-shadow 0.3s;
        }
        textarea:focus {
            border-color: var(--primary);
            box-shadow: 0 0 15px rgba(111, 66, 193, 0.25);
        }

        .btn-row {
            display: flex;
            gap: 12px;
            margin-top: 22px;
        }

        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-weight: 600;
            font-size: 15px;
            font-family: 'Inter', sans-serif;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: transform 0.2s, box-shadow 0.3s;
        }
        .btn:hover { transform: translateY(-2px); }

        .btn-send {
            background: linear-gradient(135deg, var(--glow-work), #27ae60);
            color: white;
        }
        .btn-send:hover {
            box-shadow: 0 8px 25px rgba(46, 204, 113, 0.4);
        }

        .btn-discard {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--glass);
            color: var(--text-muted);
        }
        .btn-discard:hover {
            color: white;
            border-color: rgba(255, 255, 255, 0.2);
        }
    </style>
</head>
<body>
    <div class="glass-card">
        <div class="card-header">
            <div class="icon">✨</div>
            <h2>AI Suggested Reply</h2>
        </div>
        <%
            String senderName = (String) request.getAttribute("senderName");
            String aiReply    = (String) request.getAttribute("aiReply");
            boolean aiError   = aiReply == null
                || aiReply.startsWith("AI is currently")
                || aiReply.startsWith("AI returned an error")
                || aiReply.startsWith("Could not parse")
                || aiReply.startsWith("AI is currently offline");
        %>
        <p class="recipient">To: <strong><%= escAttr(senderName) %></strong></p>
        <hr class="divider">

        <% if (aiError) { %>
            <div style="background: rgba(255,71,87,0.1); border: 1px solid rgba(255,71,87,0.35);
                        border-radius: 12px; padding: 16px 18px; margin-bottom: 18px;
                        color: #fca5a5; font-size: 14px; line-height: 1.6;">
                <strong style="display:block; margin-bottom:6px;">⚠️ AI failed to generate a reply</strong>
                <%= escAttr(aiReply) %>
            </div>
            <div class="btn-row">
                <a href="emails" class="btn btn-send" style="background: linear-gradient(135deg,#6f42c1,#8559da);">← Try Again from Inbox</a>
                <a href="emails" class="btn btn-discard">Discard</a>
            </div>
        <% } else { %>
            <form action="send-reply" method="post">
                <input type="hidden" name="recipient" value="<%= escAttr(senderName) %>">
                <input type="hidden" name="subject"   value="Re: (AI Reply)">
                <%
                    Object emailIdAttr = request.getAttribute("emailId");
                    if (emailIdAttr != null && !emailIdAttr.toString().isEmpty()) {
                %>
                <input type="hidden" name="emailId" value="<%= escAttr(emailIdAttr.toString()) %>">
                <% } %>

                <label>Edit the AI's suggestion before sending</label>
                <textarea name="finalMessage"><%= escAttr(aiReply) %></textarea>

                <div class="btn-row">
                    <button type="submit" class="btn btn-send">Approve &amp; Send ✅</button>
                    <a href="emails" class="btn btn-discard">Discard</a>
                </div>
            </form>
        <% } %>
    </div>
</body>
</html>