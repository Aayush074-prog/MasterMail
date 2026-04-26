<%@ page import="com.mastermail.model.*, java.util.*" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>MasterMail - Buckets</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --glass: rgba(255, 255, 255, 0.05);
            --primary: #6f42c1;
            --primary-hover: #8559da;
            --green: #28a745;
            --bg: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.55);
            --text-muted: #94a3b8;
            --glow-security: #ff4757;
            --glow-personal: #3498db;
            --glow-work: #2ecc71;
            --glow-promotions: #f39c12;
        }

        * { box-sizing: border-box; }

        body {
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            color: white;
            font-family: 'Inter', sans-serif;
            margin: 0; padding: 40px;
            min-height: 100vh;
        }

        .back-link {
            color: var(--text-muted);
            text-decoration: none;
            display: inline-block;
            margin-bottom: 20px;
            transition: 0.3s;
        }
        .back-link:hover { color: white; }

        h2, h3 { margin-top: 0; font-weight: 600; }

        .glass-card {
            background: var(--card-bg);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid var(--glass);
            border-radius: 16px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }

        input, select {
            background: rgba(15, 23, 42, 0.7);
            border: 1px solid var(--glass);
            color: white;
            padding: 12px 15px;
            border-radius: 8px;
            font-size: 14px;
            font-family: 'Inter', sans-serif;
            outline: none;
            transition: border-color 0.3s;
        }
        input:focus, select:focus { border-color: var(--primary); }

        .btn-create {
            padding: 12px 25px;
            background: linear-gradient(135deg, var(--primary), var(--primary-hover));
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            font-family: 'Inter', sans-serif;
            transition: 0.3s;
        }
        .btn-create:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(111, 66, 193, 0.3); }

        .btn-delete {
            background: transparent;
            border: 1px solid #ef4444;
            color: #ef4444;
            padding: 6px 14px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 12px;
            font-family: 'Inter', sans-serif;
            transition: 0.3s;
        }
        .btn-delete:hover { background: rgba(239, 68, 68, 0.15); }

        .btn-add-rule {
            background: transparent;
            border: 1px solid var(--primary);
            color: var(--primary);
            padding: 6px 14px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 12px;
            font-family: 'Inter', sans-serif;
            transition: 0.3s;
        }
        .btn-add-rule:hover { background: rgba(111, 66, 193, 0.15); }

        /* Bucket cards */
        .bucket-row {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--glass);
            border-radius: 12px;
            padding: 18px 22px;
            margin-bottom: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: 0.3s;
        }
        .bucket-row:hover { border-color: rgba(255,255,255,0.1); }

        .bucket-row.glow-security  { border-left: 3px solid var(--glow-security); }
        .bucket-row.glow-personal  { border-left: 3px solid var(--glow-personal); }
        .bucket-row.glow-work      { border-left: 3px solid var(--glow-work); }
        .bucket-row.glow-promotions{ border-left: 3px solid var(--glow-promotions); }

        .bucket-name { font-size: 16px; font-weight: 600; }
        .bucket-type { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; padding: 3px 8px; border-radius: 4px; }
        .type-default { color: var(--glow-work); background: rgba(46,204,113,0.1); }
        .type-custom  { color: var(--primary); background: rgba(111,66,193,0.1); }

        .rule-badge {
            color: var(--primary);
            font-weight: 600;
            background: rgba(111, 66, 193, 0.1);
            padding: 4px 8px;
            border-radius: 4px;
        }

        .rule-line {
            color: var(--text-muted);
            font-size: 13px;
            margin-top: 4px;
        }

        .section-label {
            font-size: 12px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 1.5px;
            margin: 25px 0 12px 0;
        }

        /* Add rule inline form */
        .add-rule-form {
            display: none;
            margin-top: 10px;
            padding-top: 10px;
            border-top: 1px solid var(--glass);
        }
        .add-rule-form.show { display: flex; }
    </style>
</head>
<body>

    <a href="emails" class="back-link">← Back to Inbox</a>
    <h2>Bucket & Rule Manager</h2>

    <%-- CREATE NEW CUSTOM BUCKET --%>
    <div class="glass-card">
        <h3>✨ Create Custom Bucket</h3>
        <p style="color: var(--text-muted); font-size: 14px; margin-bottom: 20px;">
            Create a new folder and set an automatic sorting rule in one step.
        </p>

        <form action="buckets" method="post">
            <input type="hidden" name="action" value="createBucketAndRule">

            <div style="display: flex; flex-wrap: wrap; align-items: center; gap: 10px;">
                <div>
                    <label style="font-size: 12px; color: var(--text-muted);">Bucket Name</label><br>
                    <input type="text" name="bucketName" placeholder="e.g. Homework" required style="margin-top: 6px;">
                </div>

                <div style="margin-top: 20px; font-weight: bold; color: var(--primary);">➔</div>

                <div>
                    <label style="font-size: 12px; color: var(--text-muted);">If email matches...</label><br>
                    <div style="display: flex; gap: 6px; margin-top: 6px;">
                        <select name="ruleType">
                            <option value="sender">Sender Name</option>
                            <option value="keyword">Subject Keyword</option>
                        </select>
                        <input type="text" name="ruleValue" placeholder="e.g. Aayush" required>
                    </div>
                </div>
            </div>

            <button type="submit" class="btn-create" style="margin-top: 20px;">
                ✨ Create Bucket & Rule
            </button>
        </form>
    </div>

    <%-- BUCKET LIST --%>
    <%
        List<Bucket> bucketList = (List<Bucket>) request.getAttribute("bucketList");

        // Group buckets: collect unique bucket_ids and their rules
        java.util.LinkedHashMap<Integer, Bucket> uniqueBuckets = new java.util.LinkedHashMap<>();
        java.util.LinkedHashMap<Integer, List<String[]>> bucketRules = new java.util.LinkedHashMap<>();

        if (bucketList != null) {
            for (Bucket b : bucketList) {
                int bid = b.getId();
                if (!uniqueBuckets.containsKey(bid)) {
                    uniqueBuckets.put(bid, b);
                    bucketRules.put(bid, new java.util.ArrayList<>());
                }
                if (b.getRulePattern() != null && !b.getRulePattern().isEmpty()) {
                    bucketRules.get(bid).add(new String[]{ b.getRuleType(), b.getRulePattern() });
                }
            }
        }

        // Separate defaults and customs
        List<Integer> defaultIds = new java.util.ArrayList<>();
        List<Integer> customIds = new java.util.ArrayList<>();
        for (var entry : uniqueBuckets.entrySet()) {
            if (entry.getValue().isDefault()) defaultIds.add(entry.getKey());
            else customIds.add(entry.getKey());
        }
    %>

    <%-- DEFAULT BUCKETS --%>
    <p class="section-label">🔒 Default Buckets (cannot be deleted)</p>
    <%
        for (int bid : defaultIds) {
            Bucket b = uniqueBuckets.get(bid);
            List<String[]> rules = bucketRules.get(bid);
            String glowClass = "";
            String nm = b.getName().toLowerCase();
            if (nm.contains("security")) glowClass = "glow-security";
            else if (nm.contains("personal")) glowClass = "glow-personal";
            else if (nm.contains("work")) glowClass = "glow-work";
            else if (nm.contains("promotion")) glowClass = "glow-promotions";
    %>
        <div class="bucket-row <%= glowClass %>">
            <div style="flex: 1;">
                <div style="display: flex; align-items: center; gap: 10px;">
                    <span class="bucket-name"><%= b.getName() %></span>
                    <span class="bucket-type type-default">Default</span>
                </div>
                <% if (rules.isEmpty()) { %>
                    <div class="rule-line" style="font-style: italic;">No sorting rules yet — add one below</div>
                <% } else { for (String[] r : rules) { %>
                    <div class="rule-line">
                        Move here if <span style="color: white;"><%= r[0] %></span> contains
                        <span class="rule-badge">"<%= r[1] %>"</span>
                    </div>
                <% } } %>

                <%-- Add rule form --%>
                <form action="buckets" method="post" style="display: flex; gap: 8px; align-items: center; margin-top: 10px; flex-wrap: wrap;">
                    <input type="hidden" name="action" value="addRule">
                    <input type="hidden" name="bucketId" value="<%= bid %>">
                    <select name="ruleType" style="padding: 8px 10px; font-size: 12px;">
                        <option value="sender">Sender</option>
                        <option value="keyword">Keyword</option>
                    </select>
                    <input type="text" name="ruleValue" placeholder="e.g. noreply@google.com" required
                           style="padding: 8px 10px; font-size: 12px; flex: 1; min-width: 150px;">
                    <button type="submit" class="btn-add-rule">+ Add Rule</button>
                </form>
            </div>
        </div>
    <% } %>

    <%-- CUSTOM BUCKETS --%>
    <% if (!customIds.isEmpty()) { %>
        <p class="section-label">🎨 Your Custom Buckets</p>
        <%
            for (int bid : customIds) {
                Bucket b = uniqueBuckets.get(bid);
                List<String[]> rules = bucketRules.get(bid);
        %>
            <div class="bucket-row">
                <div style="flex: 1;">
                    <div style="display: flex; align-items: center; gap: 10px;">
                        <span class="bucket-name"><%= b.getName() %></span>
                        <span class="bucket-type type-custom">Custom</span>
                    </div>
                    <% if (rules.isEmpty()) { %>
                        <div class="rule-line" style="font-style: italic;">No sorting rules</div>
                    <% } else { for (String[] r : rules) { %>
                        <div class="rule-line">
                            Move here if <span style="color: white;"><%= r[0] %></span> contains
                            <span class="rule-badge">"<%= r[1] %>"</span>
                        </div>
                    <% } } %>

                    <%-- Add rule form --%>
                    <form action="buckets" method="post" style="display: flex; gap: 8px; align-items: center; margin-top: 10px; flex-wrap: wrap;">
                        <input type="hidden" name="action" value="addRule">
                        <input type="hidden" name="bucketId" value="<%= bid %>">
                        <select name="ruleType" style="padding: 8px 10px; font-size: 12px;">
                            <option value="sender">Sender</option>
                            <option value="keyword">Keyword</option>
                        </select>
                        <input type="text" name="ruleValue" placeholder="e.g. newsletter" required
                               style="padding: 8px 10px; font-size: 12px; flex: 1; min-width: 150px;">
                        <button type="submit" class="btn-add-rule">+ Add Rule</button>
                    </form>
                </div>

                <form action="buckets" method="post" style="margin: 0; margin-left: 15px;">
                    <input type="hidden" name="action" value="deleteBucket">
                    <input type="hidden" name="bucketId" value="<%= bid %>">
                    <button type="submit" class="btn-delete"
                            onclick="return confirm('Delete bucket \'<%= b.getName() %>\' and all its rules?');">
                        🗑️ Delete
                    </button>
                </form>
            </div>
        <% } %>
    <% } %>

    <% if (uniqueBuckets.isEmpty()) { %>
        <div style="text-align:center; color: var(--text-muted); padding: 40px;">
            No buckets found. Use the creator above to start sorting!
        </div>
    <% } %>

</body>
</html>