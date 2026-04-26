# 🚀 MasterMail.ai — Deployment & Sharing Guide
# ================================================
# Share your app with friends so they can test on their own devices!

## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## OPTION 1: ngrok (EASIEST — 2 minutes)
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## This tunnels your local Tomcat to a public URL.
## Friends open the URL on their phone/laptop — done!

### Step 1: Make sure Tomcat 11 is running on port 8081
###         (Run/Debug from IntelliJ as usual)

### Step 2: Open a NEW terminal and run:
###   ngrok http 8081

### Step 3: You'll see something like:
###   Forwarding  https://abc123.ngrok-free.app -> http://localhost:8081
###
### Send that URL to friends! They open:
###   https://abc123.ngrok-free.app/MasterMail/login.jsp

### IMPORTANT NOTES:
### - Free ngrok URL changes every time you restart ngrok
### - Free tier: 1 tunnel, up to ~40 connections/minute
### - Sign up at https://ngrok.com for a free authtoken:
###     ngrok config add-authtoken YOUR_TOKEN_HERE
### - Your PC must stay ON and Tomcat must stay running


## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## OPTION 2: Same WiFi Network (No Internet Needed)
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### Step 1: Find your local IP address:
###   ipconfig
###   Look for "IPv4 Address" under your WiFi adapter (e.g., 192.168.1.105)

### Step 2: Make sure Windows Firewall allows port 8081:
###   (Run as Admin in PowerShell)
###   New-NetFirewallRule -DisplayName "Tomcat 8081" -Direction Inbound -Port 8081 -Protocol TCP -Action Allow

### Step 3: Friends on the SAME WiFi open:
###   http://192.168.1.105:8081/MasterMail/login.jsp


## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## OPTION 3: Railway.app (FREE Cloud Deploy — Permanent URL)
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### This deploys MasterMail to the internet permanently.
### Requires: Docker (optional) or just push to GitHub.

### Quick Steps:
### 1. Push your code to GitHub
### 2. Go to https://railway.app → "New Project" → "Deploy from GitHub"
### 3. Add a MySQL service (free 500MB)
### 4. Set environment variables:
###      DB_URL=jdbc:mysql://${{MySQL.MYSQL_HOST}}:${{MySQL.MYSQL_PORT}}/mastermail_db
###      DB_USER=${{MySQL.MYSQL_USER}}
###      DB_PASS=${{MySQL.MYSQL_PASSWORD}}
### 5. Railway gives you a public URL like:
###      https://mastermail-production.up.railway.app/


## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## PRE-DEPLOYMENT CHECKLIST
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 1. Run the SQL migration first:
###    Open MySQL Workbench → Run: sql/deploy_multiuser_fix.sql

### 2. Build the WAR:
###    IntelliJ → Maven panel → Lifecycle → "clean" then "package"
###    OR in terminal:
###    $env:JAVA_HOME = "C:\Program Files\Java\jdk-23"
###    & "C:\Program Files\JetBrains\IntelliJ IDEA 2025.3.3\plugins\maven\lib\maven3\bin\mvn.cmd" clean package
###    WAR file: target/MasterMail.war

### 3. Deploy to Tomcat:
###    Copy target/MasterMail.war → C:\path\to\tomcat11\webapps\
###    Tomcat auto-deploys it at: http://localhost:8081/MasterMail/

### 4. Each user must:
###    a) Register an account (gets OTP verification email)
###    b) After login, enter THEIR OWN Gmail + App Password
###    c) Click "Sync Gmail" to pull their own emails
###    (No one shares your Gmail credentials!)


## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## MULTI-USER TESTING TIPS
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### SAME PC, DIFFERENT ACCOUNTS:
### - Use Chrome for User A, Firefox for User B (different session cookies)
### - Or use Chrome Incognito for the second user
### - Each browser = independent session = no cross-contamination

### DIFFERENT DEVICES:
### - Use ngrok → each friend opens the URL on their phone/laptop
### - Each person registers their own account
### - Each person links their OWN Gmail (with their own App Password)
### - Their inbox shows ONLY their emails (user_id isolation)

### HOW TO CREATE A GMAIL APP PASSWORD:
### 1. Go to https://myaccount.google.com/apppasswords
### 2. (Must have 2-Step Verification enabled first)
### 3. Select app = "Mail", device = "Windows Computer"
### 4. Click "Generate" → Copy the 16-character password
### 5. Paste it into MasterMail's "App Password" field

