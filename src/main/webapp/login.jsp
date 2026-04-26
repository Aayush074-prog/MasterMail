<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>MasterMail.ai — Login</title>
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
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            background: var(--bg);
            background: linear-gradient(135deg, #0f172a 0%, #1a1a2e 40%, #16213e 100%);
            color: white;
            font-family: 'Inter', sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
        }

        /* Ambient glow orbs */
        body::before, body::after {
            content: '';
            position: fixed;
            border-radius: 50%;
            filter: blur(80px);
            opacity: 0.15;
            z-index: 0;
            animation: floatOrb 8s ease-in-out infinite alternate;
        }
        body::before {
            width: 400px; height: 400px;
            background: var(--glow-security);
            top: -100px; left: -100px;
        }
        body::after {
            width: 350px; height: 350px;
            background: var(--glow-personal);
            bottom: -80px; right: -80px;
            animation-delay: 2s;
        }

        @keyframes floatOrb {
            0% { transform: translate(0, 0) scale(1); }
            100% { transform: translate(40px, 30px) scale(1.15); }
        }

        .login-wrapper {
            position: relative;
            z-index: 1;
            width: 100%;
            max-width: 420px;
            padding: 20px;
        }

        .brand {
            text-align: center;
            margin-bottom: 30px;
        }
        .brand h1 {
            font-size: 32px;
            font-weight: 700;
            background: linear-gradient(135deg, var(--primary), var(--glow-personal));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .brand p {
            color: var(--text-muted);
            font-size: 14px;
            margin-top: 6px;
        }

        .glass-card {
            background: var(--card-bg);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid var(--glass);
            border-radius: 20px;
            padding: 40px 35px;
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.3);
        }

        .glass-card h2 {
            font-size: 22px;
            font-weight: 600;
            margin-bottom: 8px;
        }
        .glass-card .subtitle {
            color: var(--text-muted);
            font-size: 13px;
            margin-bottom: 28px;
        }

        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            font-size: 12px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
        }
        .form-group input {
            width: 100%;
            background: rgba(15, 23, 42, 0.7);
            border: 1px solid var(--glass);
            color: white;
            padding: 14px 16px;
            border-radius: 10px;
            font-size: 15px;
            font-family: 'Inter', sans-serif;
            transition: border-color 0.3s, box-shadow 0.3s;
            outline: none;
        }
        .form-group input:focus {
            border-color: var(--primary);
            box-shadow: 0 0 15px rgba(111, 66, 193, 0.25);
        }
        .form-group input::placeholder {
            color: #475569;
        }

        .login-btn {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, var(--primary), var(--primary-hover));
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            font-family: 'Inter', sans-serif;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.3s;
            margin-top: 10px;
        }
        .login-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(111, 66, 193, 0.4);
        }

        .footer-link {
            text-align: center;
            margin-top: 24px;
            font-size: 14px;
            color: var(--text-muted);
        }
        .footer-link a {
            color: var(--primary);
            text-decoration: none;
            font-weight: 600;
            transition: color 0.3s;
        }
        .footer-link a:hover { color: var(--primary-hover); }

        .error-msg {
            background: rgba(255, 71, 87, 0.12);
            border: 1px solid rgba(255, 71, 87, 0.3);
            color: var(--glow-security);
            padding: 12px 16px;
            border-radius: 10px;
            font-size: 13px;
            margin-bottom: 20px;
            text-align: center;
        }
        .success-msg {
            background: rgba(46, 204, 113, 0.12);
            border: 1px solid rgba(46, 204, 113, 0.3);
            color: var(--glow-work);
            padding: 12px 16px;
            border-radius: 10px;
            font-size: 13px;
            margin-bottom: 20px;
            text-align: center;
        }

        /* Category glow dots in header */
        .glow-dots {
            display: flex;
            justify-content: center;
            gap: 12px;
            margin-top: 12px;
        }
        .glow-dot {
            width: 8px; height: 8px;
            border-radius: 50%;
            animation: glowPulse 3s ease-in-out infinite;
        }
        .glow-dot.security { --glow-color: 255, 71, 87; background: var(--glow-security); }
        .glow-dot.personal { --glow-color: 52, 152, 219; background: var(--glow-personal); animation-delay: 0.5s; }
        .glow-dot.work     { --glow-color: 46, 204, 113; background: var(--glow-work); animation-delay: 1s; }

        @keyframes glowPulse {
            0%   { box-shadow: 0 0 4px rgba(var(--glow-color), 0.3); }
            50%  { box-shadow: 0 0 14px rgba(var(--glow-color), 0.7); }
            100% { box-shadow: 0 0 4px rgba(var(--glow-color), 0.3); }
        }
    </style>
</head>
<body>
    <div class="login-wrapper">
        <div class="brand">
            <h1>MasterMail.ai</h1>
            <p>Your Intelligent Inbox, Perfected.</p>
            <div class="glow-dots">
                <span class="glow-dot security"></span>
                <span class="glow-dot personal"></span>
                <span class="glow-dot work"></span>
            </div>
        </div>

        <div class="glass-card">
            <h2>Welcome Back</h2>
            <p class="subtitle">Sign in to access your secure inbox</p>

            <% if ("1".equals(request.getParameter("error"))) { %>
                <div class="error-msg">Invalid email or password. Please try again.</div>
            <% } %>
            <% if ("success".equals(request.getParameter("msg"))) { %>
                <div class="success-msg">Account created! You can now log in.</div>
            <% } %>
            <% if ("reset".equals(request.getParameter("msg"))) { %>
                <div class="success-msg">✅ Password reset successfully! Sign in with your new password.</div>
            <% } %>

            <form action="auth" method="post">
                <input type="hidden" name="action" value="login">
                <div class="form-group">
                    <label>Email Address</label>
                    <input type="email" name="email" placeholder="you@example.com" required>
                </div>
                <div class="form-group">
                    <label>Password</label>
                    <input type="password" name="pass" placeholder="Enter your password" required>
                </div>
                <button type="submit" class="login-btn">Sign In</button>
            </form>

            <div class="footer-link" style="margin-top:16px;">
                <a href="forgot-password.jsp" style="font-size:13px; color:var(--text-muted); font-weight:400;">Forgot your password?</a>
            </div>
            <div class="footer-link">
                Don't have an account? <a href="register.jsp">Create one</a>
            </div>
        </div>
    </div>
</body>
</html>