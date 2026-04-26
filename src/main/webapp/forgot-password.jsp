<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>MasterMail.ai — Forgot Password</title>
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
            background: linear-gradient(135deg, #0f172a 0%, #1a1a2e 40%, #16213e 100%);
            color: white;
            font-family: 'Inter', sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
        }

        body::before, body::after {
            content: '';
            position: fixed;
            border-radius: 50%;
            filter: blur(80px);
            opacity: 0.15;
            z-index: 0;
            animation: floatOrb 8s ease-in-out infinite alternate;
        }
        body::before { width: 400px; height: 400px; background: var(--primary); top: -100px; left: -100px; }
        body::after  { width: 350px; height: 350px; background: var(--glow-personal); bottom: -80px; right: -80px; animation-delay: 2s; }

        @keyframes floatOrb {
            0%   { transform: translate(0, 0) scale(1); }
            100% { transform: translate(40px, 30px) scale(1.15); }
        }

        .wrapper { position: relative; z-index: 1; width: 100%; max-width: 420px; padding: 20px; }

        .brand { text-align: center; margin-bottom: 30px; }
        .brand h1 {
            font-size: 32px; font-weight: 700;
            background: linear-gradient(135deg, var(--primary), var(--glow-personal));
            -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;
        }
        .brand p { color: var(--text-muted); font-size: 14px; margin-top: 6px; }

        .glow-dots { display: flex; justify-content: center; gap: 12px; margin-top: 12px; }
        .glow-dot { width: 8px; height: 8px; border-radius: 50%; animation: glowPulse 3s ease-in-out infinite; }
        .glow-dot.security { --glow-color: 255,71,87;  background: var(--glow-security); }
        .glow-dot.personal { --glow-color: 52,152,219; background: var(--glow-personal); animation-delay: 0.5s; }
        .glow-dot.work     { --glow-color: 46,204,113; background: var(--glow-work);     animation-delay: 1s; }
        @keyframes glowPulse {
            0%,100% { box-shadow: 0 0 4px rgba(var(--glow-color), 0.3); }
            50%     { box-shadow: 0 0 14px rgba(var(--glow-color), 0.7); }
        }

        .glass-card {
            background: var(--card-bg); backdrop-filter: blur(15px); -webkit-backdrop-filter: blur(15px);
            border: 1px solid var(--glass); border-radius: 20px; padding: 40px 35px;
            box-shadow: 0 15px 40px rgba(0,0,0,0.3); text-align: center;
        }
        .lock-icon { font-size: 48px; margin-bottom: 16px; display: block; }
        .glass-card h2 { font-size: 22px; font-weight: 600; margin-bottom: 8px; }
        .glass-card .subtitle { color: var(--text-muted); font-size: 13px; margin-bottom: 28px; }

        .form-group { margin-bottom: 20px; text-align: left; }
        .form-group label { display: block; font-size: 12px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
        .form-group input {
            width: 100%; background: rgba(15,23,42,0.7); border: 1px solid var(--glass);
            color: white; padding: 14px 16px; border-radius: 10px; font-size: 15px;
            font-family: 'Inter', sans-serif; transition: border-color 0.3s, box-shadow 0.3s; outline: none;
        }
        .form-group input:focus { border-color: var(--primary); box-shadow: 0 0 15px rgba(111,66,193,0.25); }
        .form-group input::placeholder { color: #475569; }

        .submit-btn {
            width: 100%; padding: 14px;
            background: linear-gradient(135deg, var(--primary), var(--primary-hover));
            color: white; border: none; border-radius: 10px; font-size: 16px; font-weight: 600;
            font-family: 'Inter', sans-serif; cursor: pointer; transition: transform 0.2s, box-shadow 0.3s; margin-top: 4px;
        }
        .submit-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 25px rgba(111,66,193,0.4); }

        .error-msg {
            background: rgba(255,71,87,0.12); border: 1px solid rgba(255,71,87,0.3);
            color: var(--glow-security); padding: 12px 16px; border-radius: 10px;
            font-size: 13px; margin-bottom: 20px; text-align: left;
        }
        .back-link { display: block; text-align: center; margin-top: 20px; font-size: 13px; color: var(--text-muted); text-decoration: none; }
        .back-link:hover { color: white; }
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="brand">
            <h1>MasterMail.ai</h1>
            <p>Reset your account password</p>
            <div class="glow-dots">
                <span class="glow-dot security"></span>
                <span class="glow-dot personal"></span>
                <span class="glow-dot work"></span>
            </div>
        </div>

        <div class="glass-card">
            <span class="lock-icon">🔑</span>
            <h2>Forgot Password?</h2>
            <p class="subtitle">Enter your account email and we'll send you a verification code to reset your password.</p>

            <% if ("1".equals(request.getParameter("error"))) { %>
                <div class="error-msg">Please enter a valid email address.</div>
            <% } else if ("2".equals(request.getParameter("error"))) { %>
                <div class="error-msg">No account found with that email address.</div>
            <% } else if ("3".equals(request.getParameter("error"))) { %>
                <div class="error-msg">Could not send verification email. Please try again.</div>
            <% } else if ("4".equals(request.getParameter("error"))) { %>
                <div class="error-msg">Verification code expired. Please start over.</div>
            <% } else if ("5".equals(request.getParameter("error"))) { %>
                <div class="error-msg">Too many failed attempts. Please start over.</div>
            <% } %>

            <form action="auth" method="post">
                <input type="hidden" name="action" value="forgot-password">
                <div class="form-group">
                    <label>Email Address</label>
                    <input type="email" name="email" placeholder="you@example.com" required autofocus>
                </div>
                <button type="submit" class="submit-btn">Send Verification Code →</button>
            </form>
        </div>

        <a href="login.jsp" class="back-link">← Back to Sign In</a>
    </div>
</body>
</html>
