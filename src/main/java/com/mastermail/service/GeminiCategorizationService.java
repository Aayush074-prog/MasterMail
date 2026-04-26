package com.mastermail.service;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.mastermail.util.ConfigLoader;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Set;

public class GeminiCategorizationService {

    private static final String API_KEY = ConfigLoader.getGeminiApiKey();
    private static final String ENDPOINT =
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + API_KEY;

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(8))
            .build();

    private static final Set<String> VALID_CATEGORIES = Set.of(
            "needs_decision", "needs_attention", "ignored_safely");

    /**
     * Categorizes an email using Gemini 2.0 Flash with user-specific few-shot rules.
     * Falls back to keyword-based logic if the API call fails.
     *
     * @param rules List of [senderPattern, preferredPriority] pairs from ai_feedback_rules
     */
    public static String categorize(int userId, String sender, String subject, String body, List<String[]> rules) {
        try {
            String prompt = buildPrompt(sender, subject, body, rules);
            String requestJson = buildRequestJson(prompt);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ENDPOINT))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestJson))
                    .timeout(Duration.ofSeconds(10))
                    .build();

            HttpResponse<String> response = HTTP.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                String category = parseCategory(response.body());
                if (category != null) {
                    System.out.println("[GEMINI] user_id=" + userId + " sender=" + sender + " → " + category);
                    return category;
                }
            }
            System.out.println("[GEMINI] Unexpected response status=" + response.statusCode() + ", using fallback");
        } catch (Exception e) {
            System.out.println("[GEMINI] API error (" + e.getClass().getSimpleName() + ": " + e.getMessage() + "), using fallback");
        }
        return fallbackCategorize(sender, subject, body);
    }

    private static String buildPrompt(String sender, String subject, String body, List<String[]> rules) {
        StringBuilder sb = new StringBuilder();
        sb.append("You are an email priority classifier. Classify the email into EXACTLY one of these categories:\n");
        sb.append("- needs_decision: Requires user action (OTPs, approvals, payments, deadlines, security alerts)\n");
        sb.append("- needs_attention: Important but informational (personal mail, receipts, shipping updates)\n");
        sb.append("- ignored_safely: Safe to skip (newsletters, promotions, marketing)\n\n");

        if (rules != null && !rules.isEmpty()) {
            sb.append("[USER PREFERENCE RULES - apply these first]:\n");
            for (String[] rule : rules) {
                sb.append("Emails from \"").append(rule[0]).append("\" → ").append(rule[1]).append("\n");
            }
            sb.append("\n");
        }

        sb.append("Email to classify:\n");
        sb.append("From: ").append(sender != null ? sender : "Unknown").append("\n");
        sb.append("Subject: ").append(subject != null ? subject : "(No Subject)").append("\n");
        String snippet = body != null ? body.substring(0, Math.min(body.length(), 500)) : "";
        sb.append("Body (first 500 chars): ").append(snippet).append("\n\n");
        sb.append("Respond with ONLY the category name. No explanation, no punctuation.");

        return sb.toString();
    }

    private static String buildRequestJson(String prompt) {
        JsonObject part = new JsonObject();
        part.addProperty("text", prompt);

        com.google.gson.JsonArray parts = new com.google.gson.JsonArray();
        parts.add(part);

        JsonObject content = new JsonObject();
        content.add("parts", parts);

        com.google.gson.JsonArray contents = new com.google.gson.JsonArray();
        contents.add(content);

        JsonObject genConfig = new JsonObject();
        genConfig.addProperty("maxOutputTokens", 20);
        genConfig.addProperty("temperature", 0.1);

        JsonObject root = new JsonObject();
        root.add("contents", contents);
        root.add("generationConfig", genConfig);

        return root.toString();
    }

    private static String parseCategory(String responseBody) {
        try {
            JsonObject obj = JsonParser.parseString(responseBody).getAsJsonObject();
            String text = obj.getAsJsonArray("candidates")
                    .get(0).getAsJsonObject()
                    .getAsJsonObject("content")
                    .getAsJsonArray("parts")
                    .get(0).getAsJsonObject()
                    .get("text").getAsString()
                    .trim().toLowerCase()
                    .replaceAll("[^a-z_]", "");

            return VALID_CATEGORIES.contains(text) ? text : null;
        } catch (Exception e) {
            System.out.println("[GEMINI] Failed to parse response: " + e.getMessage());
            return null;
        }
    }

    // Keyword-based fallback — mirrors AdvancedDAO.categorizeEmail logic
    public static String fallbackCategorize(String sender, String subject, String body) {
        String senderLower = sender != null ? sender.toLowerCase() : "";
        String subjectLower = subject != null ? subject.toLowerCase() : "";
        String combined = subjectLower + " " + (body != null ? body.toLowerCase().substring(0, Math.min(body.length(), 1500)) : "");

        String[] decisionKeywords = {
            "urgent", "action required", "action needed", "deadline", "approve",
            "confirm your", "verify your", "review required", "respond by",
            "reply needed", "payment due", "invoice", "due date", "expiring soon",
            "renew your", "immediate attention", "asap", "complete your registration",
            "submit your", "sign required", "reset your password", "verify your account",
            "otp", "verification code", "security code", "login code", "passcode",
            "one-time", "one time password", "two-factor", "2fa", "mfa code",
            "suspicious activity", "unauthorized", "account locked", "security alert",
            "failed login", "password changed", "confirm this transaction"
        };
        for (String kw : decisionKeywords) {
            if (subjectLower.contains(kw) || combined.contains(kw)) return "needs_decision";
        }

        String[] ignoreKeywords = {
            "unsubscribe", "opt out", "opt-out", "manage preferences",
            "email preferences", "no longer wish to receive",
            "weekly digest", "daily digest", "monthly newsletter",
            "% off", "limited time", "special offer", "exclusive deal",
            "shop now", "buy now", "order now", "free shipping",
            "advertisement", "sponsored", "you may also like"
        };
        for (String kw : ignoreKeywords) {
            if (combined.contains(kw)) return "ignored_safely";
        }

        String[] promoSenders = {
            "newsletter@", "news@", "marketing@", "promotions@",
            "offers@", "deals@", "promo@", "campaign@", "bulk@",
            "mailchimp", "sendgrid", "constantcontact"
        };
        for (String s : promoSenders) {
            if (senderLower.contains(s)) return "ignored_safely";
        }

        return "needs_attention";
    }
}
