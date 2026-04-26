# MasterMail — System Architecture

> A full-stack, AI-augmented email management platform built on Java Servlets, MySQL, and the Gemini AI API. Designed as an intelligent layer on top of standard IMAP/SMTP to bring priority triage, security scanning, and adaptive AI learning to personal email.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Technology Stack](#2-technology-stack)
3. [Project Structure](#3-project-structure)
4. [Database Schema](#4-database-schema)
5. [Backend Map — Servlets](#5-backend-map--servlets)
6. [Backend Map — DAO Layer](#6-backend-map--dao-layer)
7. [Backend Map — Service Layer](#7-backend-map--service-layer)
8. [Frontend Map — JSP Pages](#8-frontend-map--jsp-pages)
9. [Key Workflows](#9-key-workflows)
   - [Two-Way IMAP Read/Unread Sync](#91-two-way-imap-readunread-sync)
   - [Human-in-the-Loop AI Feedback System](#92-human-in-the-loop-ai-feedback-system)
   - [Security Lab Incident Response](#93-security-lab-incident-response)
10. [Security Model](#10-security-model)
11. [Deployment Notes](#11-deployment-notes)

---

## 1. System Overview

MasterMail is a **Java EE web application** that acts as an intelligent intermediary between a user's Gmail inbox and their browser. Rather than replacing an email client, it augments one — pulling emails in via IMAP, enriching them with AI-driven priority classification, and presenting a unified incident-response dashboard.

```
┌──────────────────────────────────────────────────────────────┐
│                        User's Browser                        │
│            (JSP + Vanilla JS — inbox, security lab)         │
└────────────────────────┬─────────────────────────────────────┘
                         │  HTTP / AJAX
┌────────────────────────▼─────────────────────────────────────┐
│                    Apache Tomcat (Java EE)                    │
│                                                              │
│  ┌─────────────┐   ┌──────────────┐   ┌──────────────────┐  │
│  │  Servlets   │──▶│  AdvancedDAO │──▶│  DBConnection    │  │
│  │ (14 classes)│   │  AdminDAO    │   │  (MySQL JDBC)    │  │
│  └──────┬──────┘   └──────────────┘   └──────────────────┘  │
│         │                                                    │
│  ┌──────▼──────────────────┐                                 │
│  │  GeminiCategorizationSvc│──▶ Google Gemini 2.0 Flash API  │
│  └─────────────────────────┘                                 │
└──────────────────────────────────────────────────────────────┘
         │ IMAP (SSL/993)                │ SMTP (587/TLS)
┌────────▼────────┐             ┌────────▼────────┐
│   Gmail Server  │             │   Gmail Server  │
│  (Incoming)     │             │  (Outgoing)     │
└─────────────────┘             └─────────────────┘

┌─────────────────────────────────────┐
│       MySQL — mastermail_db         │
│  users, emails, buckets,            │
│  ai_feedback_rules,                 │
│  security_resolutions, otps,        │
│  auto_reply_rules, sent_replies...  │
└─────────────────────────────────────┘
```

### Core Responsibilities

| Layer | Responsibility |
|---|---|
| **IMAP Sync** | Pulls the latest 20 emails from Gmail using Jakarta Mail, deduplicates by RFC-822 `Message-ID`, and propagates the Gmail `\Seen` flag bidirectionally |
| **AI Categorization** | On every new email ingestion, calls Gemini 2.0 Flash with a personalized few-shot prompt to assign one of three priority tiers |
| **Feedback Loop** | When a user overrides a category, the correction is persisted as a rule in `ai_feedback_rules` and injected into future Gemini prompts for that sender |
| **Security Lab** | Scans email bodies for OTP codes (4–8 digit regex) and sensitive credential keywords; tracks resolution state and provides deep-links back to the source email |
| **Auto-Reply** | Keyword-triggered draft generation using Gemini; drafts are held for human approval before sending |

---

## 2. Technology Stack

| Component | Technology | Version |
|---|---|---|
| Runtime | Java | 23 |
| Web Container | Apache Tomcat | 10.x (Jakarta EE) |
| Servlet API | Jakarta Servlet | 6.1.0 |
| Email Protocol | Jakarta Mail (IMAP/SMTP) | 2.0.1 |
| Database | MySQL | 8.x |
| JDBC Driver | mysql-connector-j | 9.3.0 |
| AI API | Google Gemini 2.0 Flash | REST via `java.net.http.HttpClient` |
| JSON | Gson | 2.11.0 |
| Build | Apache Maven | 3.x (WAR packaging) |
| Frontend | JSP + Vanilla JavaScript | — |

---

## 3. Project Structure

```
MasterMail/
├── pom.xml
├── ARCHITECTURE.md
├── sql/                                  # Migration scripts
│   ├── admin_migration.sql
│   ├── create_auto_reply_rules.sql
│   ├── create_sent_replies.sql
│   ├── per_user_gmail.sql
│   ├── add_read_replied_status.sql
│   └── ...
└── src/main/
    ├── java/com/mastermail/
    │   ├── dao/
    │   │   ├── AdvancedDAO.java          # Primary data access object (1,400+ lines)
    │   │   └── AdminDAO.java             # Admin-only stats queries
    │   ├── model/
    │   │   ├── User.java
    │   │   ├── Email.java
    │   │   └── Bucket.java
    │   ├── service/
    │   │   └── GeminiCategorizationService.java
    │   ├── servlet/
    │   │   ├── AuthServlet.java
    │   │   ├── EmailServlet.java
    │   │   ├── AdvancedServlet.java
    │   │   ├── MarkReadServlet.java
    │   │   ├── UpdatePriorityServlet.java
    │   │   ├── ResolveAlertServlet.java
    │   │   ├── SendReplyServlet.java
    │   │   ├── MagicReplyServlet.java
    │   │   ├── RepliesServlet.java
    │   │   ├── AutoReplyServlet.java
    │   │   ├── BucketServlet.java
    │   │   ├── DismissOtpServlet.java
    │   │   ├── AdminServlet.java
    │   │   └── LogoutServlet.java
    │   └── util/
    │       └── DBConnection.java
    └── webapp/
        ├── inbox.jsp
        ├── advanced.jsp
        ├── replies.jsp
        ├── buckets.jsp
        ├── approve-reply.jsp
        ├── admin.jsp
        ├── login.jsp
        ├── register.jsp
        └── verify-otp.jsp
```

---

## 4. Database Schema

All tables live in the `mastermail_db` MySQL database. Tables without a corresponding `.sql` migration file are created lazily at runtime via `CREATE TABLE IF NOT EXISTS` in the DAO.

### `users`
The core identity table. Each user has independent Gmail credentials, enabling true multi-tenancy.

| Column | Type | Notes |
|---|---|---|
| `user_id` | INT PK AUTO_INCREMENT | |
| `name` | VARCHAR(255) | Display name |
| `email` | VARCHAR(255) UNIQUE | Login email |
| `password` | VARCHAR(255) | Hashed password |
| `role` | VARCHAR(10) | `'USER'` or `'ADMIN'` |
| `last_login` | TIMESTAMP NULL | Updated on each login |
| `gmail_email` | VARCHAR(255) NULL | Gmail address for IMAP |
| `gmail_app_password` | VARCHAR(255) NULL | 16-char Google App Password |

### `emails`
The primary email store. A UNIQUE constraint on `(user_id, message_id)` prevents duplicate syncs while allowing the same Gmail message to belong to multiple users.

| Column | Type | Notes |
|---|---|---|
| `email_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT FK → users | |
| `sender_name` | VARCHAR(500) | Full RFC-5322 `From` header |
| `subject` | VARCHAR(1000) | |
| `body` | TEXT | Extracted plain-text content |
| `category` | VARCHAR(50) | `needs_decision` / `needs_attention` / `ignored_safely` |
| `bucket_id` | INT FK → buckets NULL | NULL = uncategorized (Inbox) |
| `message_id` | VARCHAR(500) | RFC-822 `Message-ID` header |
| `created_at` | TIMESTAMP | Original sent date (preserved from IMAP) |
| `is_read` | TINYINT(1) | Synced bidirectionally with Gmail `\Seen` flag |
| `is_replied` | TINYINT(1) | Set to 1 when a reply is sent via MasterMail |
| UNIQUE | `(user_id, message_id)` | Prevents duplicate syncs per user |

### `deleted_emails` — Soft-Delete Tracker
| Column | Type | Notes |
|---|---|---|
| `email_id` | INT PK FK → emails | |
| `deleted_at` | TIMESTAMP | When the user soft-deleted it |

Emails are excluded from inbox queries via `LEFT JOIN deleted_emails ... WHERE deleted_emails.email_id IS NULL`. A re-sync automatically restores them.

### `buckets`
User-defined (and system-default) email folders. `user_id = NULL` denotes a global default bucket.

| Column | Type | Notes |
|---|---|---|
| `bucket_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT NULL FK → users | NULL = system default |
| `name` | VARCHAR(100) | Display name |

### `bucket_rules`
Rules that map emails to buckets by sender or keyword matching.

| Column | Type | Notes |
|---|---|---|
| `rule_id` | INT PK AUTO_INCREMENT | |
| `bucket_id` | INT FK → buckets | |
| `rule_type` | VARCHAR(50) | `'sender'` or `'keyword'` |
| `rule_value` | VARCHAR(255) | Pattern to match (LIKE `%value%`) |

### `ai_feedback_rules` — The AI's Memory
Persists user corrections as few-shot examples for future Gemini prompts. Created lazily by `ensureFeedbackTable()`.

| Column | Type | Notes |
|---|---|---|
| `rule_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT FK → users | |
| `sender_pattern` | VARCHAR(255) | Full sender string from the corrected email |
| `preferred_priority` | VARCHAR(50) | The category the user chose |
| `updated_at` | TIMESTAMP | Auto-updated on change |
| UNIQUE | `(user_id, sender_pattern)` | One rule per sender per user |

### `security_resolutions` — Security Audit Trail
Tracks which security findings a user has reviewed and marked safe. Created lazily by `ensureResolutionsTable()`.

| Column | Type | Notes |
|---|---|---|
| `resolution_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT FK → users | |
| `finding_key` | VARCHAR(500) | Composite key: `"type|value|sender"` |
| `resolved_at` | TIMESTAMP | When the user resolved it |
| UNIQUE | `(user_id, finding_key)` | Idempotent — safe to resolve twice |

### `otps`
Short-lived OTP codes extracted during sync, surfaced as a live alert bar on the inbox.

| Column | Type | Notes |
|---|---|---|
| `otp_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT FK → users | |
| `sender_name` | VARCHAR(500) | |
| `otp_code` | VARCHAR(10) | 4–8 digit code |
| `timestamp` | TIMESTAMP | Extracted time; used for 15-min expiry |

### `auto_reply_rules`
Keyword triggers that generate reply drafts automatically when a matching email arrives.

| Column | Type | Notes |
|---|---|---|
| `rule_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT FK → users | |
| `keyword` | VARCHAR(255) | Matched case-insensitively in subject + body |
| `reply_message` | TEXT | Draft message to generate |
| `is_active` | BOOLEAN | Togglable without deleting |
| `created_at` | TIMESTAMP | |

### `auto_drafted_replies`
Holds AI-generated or rule-triggered reply drafts pending human approval.

| Column | Type | Notes |
|---|---|---|
| `draft_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT FK → users | |
| `email_id` | INT FK → emails | Source email |
| `rule_id` | INT FK → auto_reply_rules | Triggering rule |
| `recipient_email` | VARCHAR(255) | |
| `recipient_name` | VARCHAR(255) | |
| `subject` | VARCHAR(500) | |
| `draft_message` | TEXT | |
| `created_at` | TIMESTAMP | |
| UNIQUE | `(email_id, rule_id)` | Prevents duplicate drafts per trigger |

### `sent_replies`
Conversation history for emails sent via MasterMail's reply interface.

| Column | Type | Notes |
|---|---|---|
| `reply_id` | INT PK AUTO_INCREMENT | |
| `user_id` | INT FK → users | |
| `recipient_email` | VARCHAR(255) | |
| `recipient_name` | VARCHAR(255) | |
| `subject` | VARCHAR(500) | |
| `message` | TEXT | |
| `sent_at` | TIMESTAMP | |

---

## 5. Backend Map — Servlets

Each Servlet handles a single URL and delegates all data operations to `AdvancedDAO`. Servlets never contain SQL.

### `AuthServlet` — `/auth`
Handles the complete authentication lifecycle: registration, email OTP verification, forgot-password, reset, and login.

- **POST `action=register`** → `dao.emailExists()` → `dao.registerUser()` → sends 6-digit OTP via SMTP → `verify-otp.jsp`
- **POST `action=verifyOtp`** → validates OTP from session → marks account active → `login.jsp`
- **POST `action=forgotPassword`** → `dao.emailExists()` → emails reset link → `login.jsp`
- **POST `action=resetPassword`** → `dao.updatePassword()` → `login.jsp`
- **POST `action=login`** → `dao.loginUser()` → sets `user` session attribute → `emails` (inbox)

### `EmailServlet` — `/emails`
The main inbox controller. Orchestrates sync, pagination, and credential saving.

- **GET** → optionally triggers `dao.syncGmail()` if `?action=sync`; loads paginated email list via `dao.getEmailsPage()`; fetches fresh OTPs; forwards to `inbox.jsp`
- **POST `action=saveGmail`** → `dao.saveGmailCredentials()` → updates session `User` object → redirect to `/emails`
- **POST** (default) → `dao.addEmail()` (legacy manual add) → redirect

### `AdvancedServlet` — `/advanced`
Drives the Security Lab page.

- **GET** → `dao.getEmails()` + `dao.getDeletedEmails()` + `dao.detectOTPs()` → forwards to `advanced.jsp`
- **POST `action=safeDelete`** → `dao.safeDelete(emailId)` → re-invokes `doGet`
- **POST `action=restore`** → `dao.restoreEmail(emailId)` → re-invokes `doGet`

### `MarkReadServlet` — `/mark-read`
AJAX endpoint. Handles read-state synchronization in two phases.

- **POST** → `dao.markEmailRead(emailId, userId)` (immediate, local DB) → spawns a background `Thread` that calls `dao.setGmailMessageSeen()` (IMAP flag write, non-blocking) → **204 No Content**

### `UpdatePriorityServlet` — `/update-priority`
AJAX endpoint. Implements the human-in-the-loop correction mechanism.

- **POST** → validates `newPriority` against whitelist → `dao.updateEmailCategory()` → `dao.getSenderByEmailId()` → `dao.saveFeedbackRule()` → **204 No Content**

### `ResolveAlertServlet` — `/resolve-alert`
AJAX endpoint. Closes the loop on a Security Lab finding.

- **POST** → `dao.markFindingResolved(userId, findingKey)` → **204 No Content**

### `SendReplyServlet` — `/send-reply`
Sends an email via the user's Gmail SMTP credentials and records it in the conversation history.

- **POST** → authenticates SMTP session → `Transport.send()` → `dao.saveReply()` → `dao.markEmailReplied()` → optionally `dao.deleteDraftReply()` → redirect to `/emails?replyStatus=sent`

### `MagicReplyServlet` — `/magic-reply`
Generates an AI-drafted reply using Gemini, presenting it for human approval before sending.

- **POST** → builds prompt from `emailBody` + `senderName` → calls Gemini 2.0 Flash API → parses response → sets `aiReply` attribute → forwards to `approve-reply.jsp`

### `RepliesServlet` — `/replies`
Manages the conversation history and auto-draft inbox.

- **GET** → `dao.getReplyThreads()` + `dao.getAutoDraftedReplies()` + `dao.getAutoReplyRules()` → optionally loads a specific conversation via `?threadEmail=` → `replies.jsp`
- **POST `action=approveDraft`** → forwards to `SendReplyServlet`
- **POST `action=deleteDraft`** → `dao.deleteDraftReply()`

### `AutoReplyServlet` — `/auto-reply`
Manages keyword-triggered auto-reply rules.

- **POST `action=addRule`** → `dao.addAutoReplyRule()`
- **POST `action=deleteRule`** → `dao.deleteAutoReplyRule()`
- **POST `action=toggleRule`** → `dao.toggleAutoReplyRule()` (flips `is_active`)
- All actions redirect to `/replies`

### `BucketServlet` — `/buckets`
Manages user-defined email folders and their matching rules.

- **GET** → `dao.getBuckets(userId)` → `buckets.jsp`
- **POST `action=create`** → `dao.createBucketAndReturnId()` → `dao.addRule()` → redirect
- **POST `action=addRule`** → `dao.addRule(bucketId, type, value)` → redirect
- **POST `action=delete`** → `dao.deleteBucket()` (NULLs bucket_id on affected emails) → redirect

### `DismissOtpServlet` — `/dismiss-otp`
Removes an OTP from the live alert bar and from the `otps` table.

- **POST** → `dao.deleteOtpByKey(userId, otpKey)` → updates session dismiss-set → **204 No Content**

### `AdminServlet` — `/admin`
Role-restricted dashboard. Access is gated by `user.isAdmin()` check.

- **GET** → `AdminDAO.getTotalUsersCount()` + `getActiveUsersCount()` + `getTotalEmailsCount()` + `getAllUsers()` → `admin.jsp`
- **POST `action=deleteUser`** → `AdminDAO.deleteUser(userId)` → redirect

### `LogoutServlet` — `/logout`
- **GET** → `session.invalidate()` → redirect to `login.jsp`

---

## 6. Backend Map — DAO Layer

`AdvancedDAO` is the single data-access class for all application data. It uses plain JDBC with `try-with-resources` — no ORM, no connection pool.

**Connection:** `jdbc:mysql://localhost:3306/mastermail_db` (root/root, via `DBConnection.getConnection()`)

### Authentication
| Method | SQL Table | Description |
|---|---|---|
| `emailExists(email)` | `users` | Returns true if email is registered |
| `registerUser(name, email, password)` | `users` | Inserts new user row |
| `loginUser(email, password)` | `users` | Returns hydrated `User` object or null |
| `updatePassword(email, newPassword)` | `users` | Password reset |
| `saveGmailCredentials(userId, gmail, pass)` | `users` | Updates IMAP/SMTP credentials |

### Email Inbox
| Method | SQL Table | Description |
|---|---|---|
| `getEmailsPage(userId, page, pageSize)` | `emails`, `buckets`, `deleted_emails` | Paginated inbox; excludes soft-deleted; joins bucket name |
| `countEmails(userId)` | `emails`, `deleted_emails` | Count for pagination |
| `getEmails(userId)` | `emails`, `deleted_emails` | Full unpaginated list (used by Security Lab) |
| `addEmail(userId, sender, subject, body)` | `emails` | Manual add; calls Gemini for category |
| `markEmailRead(emailId, userId)` | `emails` | Sets `is_read = 1` |
| `markEmailReplied(emailId, userId)` | `emails` | Sets `is_replied = 1`, `is_read = 1` |
| `getMessageIdByEmailId(emailId, userId)` | `emails` | Fetches RFC-822 `Message-ID` for IMAP flag write |
| `updateEmailCategory(emailId, userId, cat)` | `emails` | User priority override |
| `getSenderByEmailId(emailId, userId)` | `emails` | Fetches sender for feedback rule creation |
| `cleanOrphanedDeletes()` | `deleted_emails` | Removes stale soft-delete markers |

### Gmail Sync
| Method | Description |
|---|---|
| `syncGmail(userId, email, pass)` | IMAP fetch of latest 20 messages; deduplicates; extracts OTPs; fires auto-reply processing |
| `saveToDatabase(...)` | `INSERT ... ON DUPLICATE KEY UPDATE is_read`; calls Gemini; returns `true` if genuinely new |
| `setGmailMessageSeen(email, pass, messageId)` | Opens IMAP folder READ_WRITE; searches by `Message-ID` header; sets `\Seen` flag |
| `restoreByMessageId(userId, messageId)` | Removes soft-delete marker on re-sync |

### Buckets
| Method | SQL Table | Description |
|---|---|---|
| `getBuckets(userId)` | `buckets`, `bucket_rules` | Returns all buckets (default + user) with their rules |
| `createBucketAndReturnId(userId, name)` | `buckets` | Creates new bucket, returns generated ID |
| `addRule(bucketId, type, value)` | `bucket_rules` | Adds sender or keyword rule to a bucket |
| `deleteBucket(bucketId, userId)` | `buckets`, `emails` | Deletes bucket; NULLs `bucket_id` on orphaned emails |
| `resolveBucketId(userId, sender, subject)` | `bucket_rules`, `buckets` | Finds the best matching bucket for an incoming email |

### Security & OTP
| Method | SQL Table | Description |
|---|---|---|
| `detectOTPs(userId)` | `emails`, `security_resolutions` | Regex-scans all email bodies; returns 9-field finding array; enriches with resolved state |
| `getFreshOTPs(userId)` | `otps` | Returns OTP codes from the last 15 minutes for the alert bar |
| `extractAndStoreOTP(userId, sender, body)` | `otps` | Regex extracts 4–6 digit codes during sync; rejects years and trivial sequences |
| `deleteOtpByKey(userId, otpKey)` | `otps` | Deletes by display-key format on dismiss |
| `markFindingResolved(userId, findingKey)` | `security_resolutions` | `INSERT IGNORE` — idempotent |
| `getResolvedKeys(userId)` | `security_resolutions` | Returns set of resolved finding keys for current scan |
| `ensureResolutionsTable()` | `security_resolutions` | Lazy `CREATE TABLE IF NOT EXISTS` |

### AI Feedback
| Method | SQL Table | Description |
|---|---|---|
| `getFeedbackRules(userId)` | `ai_feedback_rules` | Returns `[senderPattern, preferredPriority]` pairs for Gemini prompt injection |
| `saveFeedbackRule(userId, sender, priority)` | `ai_feedback_rules` | `INSERT ON DUPLICATE KEY UPDATE` — upserts the correction |
| `ensureFeedbackTable()` | `ai_feedback_rules` | Lazy `CREATE TABLE IF NOT EXISTS` |
| `categorizeEmail(sender, subject, body)` | — | Pure-Java keyword classifier; used by `recategorizeAllEmails()` only |

### Soft Delete
| Method | SQL Table | Description |
|---|---|---|
| `safeDelete(emailId)` | `deleted_emails` | Inserts soft-delete marker |
| `restoreEmail(emailId)` | `deleted_emails` | Removes marker (email reappears) |
| `getDeletedEmails(userId)` | `emails`, `deleted_emails` | Returns soft-deleted emails for Trash view |

### Auto-Reply
| Method | SQL Table | Description |
|---|---|---|
| `getAutoReplyRules(userId)` | `auto_reply_rules` | Returns all rules ordered by creation time |
| `addAutoReplyRule(userId, keyword, message)` | `auto_reply_rules` | Creates new active rule |
| `deleteAutoReplyRule(ruleId, userId)` | `auto_reply_rules` | Hard delete |
| `toggleAutoReplyRule(ruleId, userId)` | `auto_reply_rules` | Flips `is_active = NOT is_active` |
| `processAutoReply(userId, emailId, ...)` | `auto_drafted_replies` | Matches active rules against incoming email; creates draft if match |
| `createDraftReply(...)` | `auto_drafted_replies` | `INSERT IGNORE` with UNIQUE `(email_id, rule_id)` guard |
| `getAutoDraftedReplies(userId)` | `auto_drafted_replies` | Returns pending drafts |
| `deleteDraftReply(draftId, userId)` | `auto_drafted_replies` | Removes after approval or dismissal |

### Sent Replies
| Method | SQL Table | Description |
|---|---|---|
| `saveReply(userId, ...)` | `sent_replies` | Records sent reply for conversation history |
| `getReplyThreads(userId)` | `sent_replies` | Groups by recipient; returns latest message + count per thread |
| `getConversation(userId, recipientEmail)` | `emails`, `sent_replies` | UNIONs received + sent, sorted chronologically |

---

## 7. Backend Map — Service Layer

### `GeminiCategorizationService`
**Package:** `com.mastermail.service`
**Pattern:** Stateless utility class with only `static` methods.

**API Endpoint:**
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={API_KEY}
```

**Request Configuration:**
```json
{
  "contents": [{ "parts": [{ "text": "<prompt>" }] }],
  "generationConfig": { "maxOutputTokens": 20, "temperature": 0.1 }
}
```

The very low `maxOutputTokens` (20) and low `temperature` (0.1) are deliberate: the model is constrained to output only the category name — no explanation, no punctuation.

**Prompt Structure (with user rules injected):**
```
You are an email priority classifier. Classify into EXACTLY one category:
- needs_decision: Requires action (OTPs, approvals, payments, deadlines, security alerts)
- needs_attention: Important but informational (personal, receipts, shipping)
- ignored_safely: Safe to skip (newsletters, promotions, marketing)

[USER PREFERENCE RULES — apply these first]:
Emails from "newsletter@company.com" → ignored_safely
Emails from "boss@work.com" → needs_decision
...

Email to classify:
From: {sender}
Subject: {subject}
Body (first 500 chars): {body snippet}

Respond with ONLY the category name. No explanation, no punctuation.
```

**Execution Flow:**
1. Call `getFeedbackRules(userId)` from DAO to load personalized rules
2. Build prompt string with rules injected as few-shot examples
3. POST to Gemini API via `java.net.http.HttpClient` (8s connect timeout, 10s request timeout)
4. Parse JSON response: `candidates[0].content.parts[0].text`
5. Validate result against `{"needs_decision", "needs_attention", "ignored_safely"}`
6. On any error (network, non-200, invalid category): call `fallbackCategorize()`

**Fallback Classifier (`fallbackCategorize`):**
Three-tier keyword matching applied in order:
- **`needs_decision`:** urgent, action required, deadline, approve, OTP, 2FA, security alert, payment due, invoice, reset password, unauthorized, account locked
- **`ignored_safely`:** unsubscribe, opt-out, newsletter, % off, shop now, advertisement; also sender patterns like `newsletter@`, `marketing@`, `mailchimp`
- **`needs_attention`:** everything else (the safe default)

---

## 8. Frontend Map — JSP Pages

All pages use a consistent dark-theme design system with CSS custom properties (`--primary: #6f42c1`, `--bg: #0f172a`, etc.) and server-side rendering via JSTL-style scriptlets.

### `inbox.jsp` — Primary Interface

**Data consumed from request attributes:**
- `emailList` (List<Email>): the current page of emails
- `currentPage`, `totalPages`, `totalCount`: for pagination
- `freshOTPs` (List<String>): OTP codes from the last 15 minutes for the alert bar
- `syncResult` (String): success/failure message from Gmail sync

**UI Sections:**
1. **Sidebar** — navigation to all major sections
2. **Gmail Link Card** — input fields to connect/update Gmail credentials
3. **OTP Alert Bar** — dismissable banners for fresh OTP codes (with one-click copy)
4. **Filter Tabs** — client-side category filter (All / Needs Decision / Needs Attention / Ignored Safely)
5. **Search Bar** — real-time text search across subject and sender fields
6. **Email Cards** — expandable rows showing category badge, subject, sender, date, read/replied status, priority override dropdown, delete button, reply section
7. **Pagination** — page navigation links

**AJAX Calls:**

| Endpoint | Trigger | Effect |
|---|---|---|
| `POST /mark-read` | Opening an unread card | Marks local DB read; sets Gmail `\Seen` flag in background |
| `POST /dismiss-otp` | Clicking dismiss on OTP banner | Removes from UI and deletes from `otps` table |
| `POST /update-priority` | Changing the "Move to..." dropdown | Updates `emails.category`; saves sender rule to `ai_feedback_rules` |

**Deep-Link Support:**
When loaded with `?highlight={emailId}`, a JavaScript IIFE on page load finds the matching card by `data-email-id`, smooth-scrolls to it, expands it, marks it read, and applies a 2.5s purple glow — enabling direct navigation from Security Lab findings.

---

### `advanced.jsp` — Security Lab

**Data consumed:**
- `inboxEmails` (List<Email>): for trash management context
- `trashEmails` (List<Email>): soft-deleted emails
- `otpList` (List<String[9]>): security findings — each entry contains `[type, value, sender, timestamp, ageStatus, epochMs, emailId, findingKey, isResolved]`

**UI Sections:**
1. **Security Scanner Table** — all findings sorted by urgency: unresolved SENSITIVE → active OTP → expired OTP → resolved
2. **Per-row Actions** — "↗ View" deep-link to inbox; "✔ Mark Safe" for unresolved SENSITIVE findings
3. **Trash / Bin** — list of soft-deleted emails with restore option

**AJAX Calls:**

| Endpoint | Trigger | Effect |
|---|---|---|
| `POST /resolve-alert` | "✔ Mark Safe" button | Records in `security_resolutions`; swaps badge to gray "✔ Resolved" live |
| `POST /dismiss-otp` | OTP dismiss | Removes from `otps` table |

**Live Countdown:**
Active OTP badges run a real-time `setInterval` countdown (MM:SS) using `data-detected-ms`. When time expires, the badge auto-transitions from green "● Active" to gray "○ Expired" without a page reload.

---

### `replies.jsp` — Conversation Center

**Data consumed:**
- `replyThreads` (List<String[]>): unique recipients with last-message preview and count
- `conversation` (List<String[]>): chronological thread of sent + received messages
- `autoDrafts` (List<String[]>): pending AI/rule-generated drafts awaiting approval
- `autoReplyRules` (List<String[]>): the user's keyword trigger rules

**UI Sections:**
1. **Thread List** — contacts the user has corresponded with
2. **Conversation View** — sent/received messages in chronological order
3. **Auto-Draft Inbox** — yellow-highlighted drafts; "Approve" sends immediately, "Delete" discards
4. **Auto-Reply Rules Panel** — create, toggle, and delete keyword-trigger rules

---

### `buckets.jsp` — Email Organization

Displays all buckets (system defaults and user-created) with their rules. Forms submit directly to `BucketServlet` for all CRUD operations.

---

### `approve-reply.jsp` — AI Reply Editor

Intermediate step between AI reply generation and sending. Displays the Gemini-generated draft in an editable textarea. Submitting the form POSTs to `SendReplyServlet`.

---

### `login.jsp` / `register.jsp` / `verify-otp.jsp`

Authentication flow pages. `verify-otp.jsp` includes a resend OTP form. All redirect through `AuthServlet`.

---

## 9. Key Workflows

### 9.1 Two-Way IMAP Read/Unread Sync

This is the most architecturally significant feature — it keeps the MasterMail read-state in lockstep with Gmail in both directions, without requiring the user to stay connected.

**Direction 1: Gmail → MasterMail (on sync)**

```
User clicks "Sync Gmail"
  │
  ▼
EmailServlet.doGet (action=sync)
  │
  ▼
AdvancedDAO.syncGmail(userId, email, appPassword)
  │
  ├─ Connect to imap.gmail.com:993 via SSL
  ├─ Open INBOX folder (READ_ONLY)
  ├─ Fetch last 20 messages
  ├─ Batch prefetch FLAGS + ENVELOPE in one round-trip (FetchProfile)
  │
  └─ For each message:
       ├─ Extract sender, subject, body (MIME text extraction)
       ├─ Extract RFC-822 Message-ID for deduplication
       ├─ Read isSeen = message.isSet(Flags.Flag.SEEN)
       │
       ▼
     AdvancedDAO.saveToDatabase(userId, sender, subject, body, messageId, sentDate, isSeen)
       │
       ├─ Load ai_feedback_rules for this user
       ├─ Call GeminiCategorizationService.categorize() → category string
       │
       ├─ INSERT INTO emails ... ON DUPLICATE KEY UPDATE is_read = VALUES(is_read)
       │    ↑ The ON DUPLICATE KEY clause syncs Gmail's \Seen state on every re-sync
       │    ↑ without overwriting any locally-managed column (category, body, etc.)
       │
       ├─ If new insert: extractAndStoreOTP(), processAutoReply()
       └─ If duplicate: restoreByMessageId() (un-deletes if user had soft-deleted it)
```

**Direction 2: MasterMail → Gmail (on card expand)**

```
User opens an unread email card
  │
  ▼
inbox.jsp JavaScript (toggleDetail function)
  ├─ Optimistic UI update: remove unread-dot, swap is-unread → is-read class
  │
  └─ fire-and-forget: fetch('mark-read', { method: 'POST', body: emailId })
       │
       ▼
     MarkReadServlet.doPost()
       ├─ dao.markEmailRead(emailId, userId)     ← immediate DB write
       │    UPDATE emails SET is_read=1 WHERE email_id=? AND user_id=?
       │
       └─ new Thread(() -> {                      ← non-blocking background thread
              dao.setGmailMessageSeen(gmailEmail, appPassword, messageId)
                ├─ Re-connect to IMAP (READ_WRITE this time)
                ├─ Search folder for message by Message-ID header
                ├─ message.setFlag(Flags.Flag.SEEN, true)
                └─ Close folder (expunge=false — never delete)
            }).start()
       │
       └─ Response: 204 No Content (browser already updated optimistically)
```

The background thread pattern ensures the IMAP write never blocks the HTTP response. If the IMAP write fails (network hiccup, token expiry), the local DB still shows the email as read — the next full sync will reconcile.

---

### 9.2 Human-in-the-Loop AI Feedback System

The AI learns from user corrections via a persistent few-shot learning mechanism. No model retraining is involved — the learning happens entirely at prompt-construction time.

```
PHASE 1: Initial Categorization (on sync or manual add)
──────────────────────────────────────────────────────
New email arrives
  │
  ▼
AdvancedDAO.saveToDatabase() or addEmail()
  │
  ├─ SELECT sender_pattern, preferred_priority
  │    FROM ai_feedback_rules WHERE user_id = ?
  │    → rules = [["newsletter@co.com","ignored_safely"], ...]
  │
  ▼
GeminiCategorizationService.categorize(userId, sender, subject, body, rules)
  │
  ├─ Construct prompt:
  │    "...
  │    [USER PREFERENCE RULES]:
  │    Emails from 'newsletter@co.com' → ignored_safely
  │    ...
  │    From: {sender}
  │    Subject: {subject}
  │    Body: {first 500 chars}
  │    Respond with ONLY the category name."
  │
  ├─ POST to Gemini 2.0 Flash API (10s timeout)
  │
  ├─ Parse response → validate ∈ {needs_decision, needs_attention, ignored_safely}
  │
  ├─ On success → return Gemini's category
  └─ On failure → fallbackCategorize() (keyword arrays, no API call)
       │
       ▼
     INSERT INTO emails (... category = ?) ...
```

```
PHASE 2: User Correction (on priority dropdown change)
──────────────────────────────────────────────────────
User sees wrong category, selects new priority from "Move to..." dropdown
  │
  ▼
inbox.jsp → updatePriority(emailId, selectEl)
  ├─ Optimistic UI: swap card CSS class, badge label, badge color
  │
  └─ fetch('update-priority', { method: 'POST', body: emailId + newPriority })
       │
       ▼
     UpdatePriorityServlet.doPost()
       ├─ Validate newPriority ∈ whitelist (prevents injection)
       │
       ├─ dao.updateEmailCategory(emailId, userId, newPriority)
       │    UPDATE emails SET category=? WHERE email_id=? AND user_id=?
       │
       ├─ dao.getSenderByEmailId(emailId, userId)
       │    → senderPattern = "Newsletter Co <newsletter@co.com>"
       │
       └─ dao.saveFeedbackRule(userId, senderPattern, newPriority)
            INSERT INTO ai_feedback_rules (user_id, sender_pattern, preferred_priority)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE preferred_priority = VALUES(preferred_priority)
       │
       └─ Response: 204 No Content
```

```
PHASE 3: Rule Applied on Next Sync
───────────────────────────────────
Next email from "Newsletter Co <newsletter@co.com>" arrives
  │
  ▼
getFeedbackRules(userId) → includes the new rule
  │
  ▼
Gemini prompt now contains:
  "Emails from 'Newsletter Co <newsletter@co.com>' → ignored_safely"
  │
  ▼
Gemini correctly categorizes as ignored_safely
  (the few-shot example in the prompt overrides Gemini's default judgment)
```

---

### 9.3 Security Lab Incident Response

A three-stage workflow for detecting, investigating, and closing security alerts.

**Stage 1: Detection (on every Security Lab page load)**

```
AdvancedServlet.doGet()
  │
  └─ dao.detectOTPs(userId)
       │
       ├─ getResolvedKeys(userId)
       │    SELECT finding_key FROM security_resolutions WHERE user_id=?
       │    → resolvedKeys = Set{"sensitive|password|Gmail <no-reply@accounts.google.com>"}
       │
       ├─ SELECT email_id, sender_name, body, created_at
       │    FROM emails WHERE user_id=? ORDER BY created_at DESC
       │
       ├─ For each email body:
       │    ├─ Run OTP regex (4-8 digits near OTP-keyword words, bidirectional)
       │    │    Reject: calendar years (2020-2039), trivial sequences (0000, 1234)
       │    │    → Dedup by "otp|{code}|{sender}" — keep newest occurrence
       │    │
       │    └─ Run keyword regex (password|secret|credential|private.?key|access.?token)
       │         → Dedup by "sensitive|{keyword}|{sender}"
       │
       ├─ Tag each finding: isResolved = resolvedKeys.contains(findingKey)
       │
       └─ Sort: unresolved SENSITIVE (0) → active OTP (1) → expired OTP (2) → resolved (3)
            Return List<String[9]> where [6]=emailId, [7]=findingKey, [8]=isResolved
```

**Stage 2: Investigate (from Security Lab → Inbox)**

```
User sees "SENSITIVE | password | from Gmail" in the scanner table
  │
  └─ Clicks "↗ View" link
       │
       ▼
     Browser navigates to: /emails?highlight={emailId}
       │
       ▼
     EmailServlet loads inbox.jsp with standard email list
       │
       ▼
     inbox.jsp JavaScript (IIFE on DOMContentLoaded):
       ├─ Read highlightId from URL param (server-rendered into JS variable)
       ├─ document.querySelector('[data-email-id="{highlightId}"]')
       ├─ card.scrollIntoView({ behavior: 'smooth', block: 'center' })
       ├─ card.classList.add('expanded')   ← opens the detail panel
       ├─ If unread: fire mark-read AJAX call
       └─ Apply box-shadow glow for 2500ms → fade out
```

**Stage 3: Resolve (closing the incident)**

```
User reads the email, determines it is a false positive or has been actioned
  │
  └─ Clicks "✔ Mark Safe" button on the SENSITIVE row
       │
       ▼
     advanced.jsp → markSafe(btn)
       ├─ findingKey = btn.getAttribute('data-finding-key')
       │    → "sensitive|password|Gmail <no-reply@accounts.google.com>"
       │
       └─ fetch('resolve-alert', { method: 'POST', body: 'findingKey=...' })
            │
            ▼
          ResolveAlertServlet.doPost()
            └─ dao.markFindingResolved(userId, findingKey)
                 INSERT IGNORE INTO security_resolutions (user_id, finding_key)
                 VALUES (?, ?)
            │
            └─ Response: 204 No Content
       │
       ▼
     JavaScript DOM update (no page reload):
       ├─ Swap .badge-sensitive → .badge-resolved ("✔ Sensitive")
       ├─ Status cell → green "✔ Resolved" badge
       ├─ Remove red row background
       └─ Remove "✔ Mark Safe" button from action cell

On next page load:
  detectOTPs() → resolvedKeys.contains("sensitive|password|...") = true
  → finding[8] = "true" → row rendered with gray badge, no Mark Safe button
```

---

## 10. Security Model

| Concern | Implementation |
|---|---|
| **Authentication** | Session-based; `User` object stored in `HttpSession`; all Servlets check `session.getAttribute("user")` |
| **Authorization** | Admin routes check `user.isAdmin()` before proceeding |
| **SQL Injection** | All queries use `PreparedStatement` with parameterized inputs |
| **XSS** | All JSP output is escaped via a local `esc()` helper (`HtmlUtils.htmlEscape` equivalent) |
| **Priority Validation** | `UpdatePriorityServlet` validates against a `Set.of(...)` whitelist |
| **IMAP Credentials** | Stored per-user in the `users` table; never exposed to the browser |
| **API Key** | Gemini API key is hardcoded in `GeminiCategorizationService` (dev mode; should use env var in production) |
| **No-Reply Guard** | Auto-reply system checks `isNoReplySender()` before creating any draft |
| **OTP False-Positive Filter** | Year range (2020–2039) and trivial sequences (0000, 1234) are explicitly rejected |

---

## 11. Deployment Notes

**Prerequisites:**
- Java 23 JDK
- Apache Tomcat 10.x (Jakarta EE 10 compatible)
- MySQL 8.x with database `mastermail_db` created
- Google Gemini API key (currently hardcoded; move to env var for production)

**Build:**
```bash
mvn clean package
# Output: target/MasterMail.war
```

**Database Setup:**
```bash
mysql -u root -p mastermail_db < sql/admin_migration.sql
mysql -u root -p mastermail_db < sql/create_auto_reply_rules.sql
mysql -u root -p mastermail_db < sql/create_sent_replies.sql
mysql -u root -p mastermail_db < sql/per_user_gmail.sql
mysql -u root -p mastermail_db < sql/add_read_replied_status.sql
# Tables: ai_feedback_rules, security_resolutions, otps
# → created automatically at runtime on first use
```

**Deploy:**
```
cp target/MasterMail.war $TOMCAT_HOME/webapps/
# Application available at: http://localhost:8080/MasterMail/
```

**Gmail Requirements:**
Each user must enable "Less Secure App Access" or generate a 16-character **Google App Password** (required if 2FA is enabled, which is recommended). The App Password is stored in `users.gmail_app_password` and used for both IMAP (port 993, SSL) and SMTP (port 587, STARTTLS).

---

*Generated from full codebase analysis — reflects the state of the MasterMail project as of April 2026.*
