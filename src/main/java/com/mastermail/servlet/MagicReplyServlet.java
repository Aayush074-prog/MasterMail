package com.mastermail.servlet;

import com.mastermail.util.ConfigLoader;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Scanner;

@WebServlet("/magic-reply")
public class MagicReplyServlet extends HttpServlet {

    private static final String[][] GEMINI_ENDPOINTS = {
        { "gemini-2.5-flash",       "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key="      },
        { "gemini-2.0-flash-001",   "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-001:generateContent?key="      },
        { "gemini-1.5-flash",       "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key="          },
        { "gemini-2.0-flash-lite-001", "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite-001:generateContent?key=" },
    };
    private static final int MAX_RETRIES = 2;
    private static final int RETRY_DELAY_MS = 2000;

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String body = request.getParameter("emailBody");
        String sender = request.getParameter("senderName");
        String apiKey = ConfigLoader.getGeminiApiKey();

        String cleanBody = sanitizeForJson(body);
        String cleanSender = sanitizeForJson(sender);

        String promptText = "You are a helpful and professional email assistant. "
                + "Write a polite, concise reply to this email from " + cleanSender + ": " + cleanBody;

        String jsonInput = "{\"contents\":[{\"parts\":[{\"text\":\"" + promptText + "\"}]}]}";

        String aiSuggestion = callGeminiWithFallback(jsonInput, apiKey);

        request.setAttribute("aiReply", aiSuggestion);
        request.setAttribute("originalBody", body);
        request.setAttribute("senderName", sender);
        request.setAttribute("emailId", request.getParameter("emailId"));
        request.getRequestDispatcher("approve-reply.jsp").forward(request, response);
    }

    /** Tries each model endpoint in order; falls back on 404 or connection error. */
    private String callGeminiWithFallback(String jsonInput, String apiKey) {
        for (String[] endpoint : GEMINI_ENDPOINTS) {
            String model = endpoint[0];
            String endpointUrl = endpoint[1];
            System.out.println("[GEMINI] Trying model: " + model);
            String result = callGeminiWithRetry(jsonInput, apiKey, endpointUrl, model);
            if (result != null) return result;
        }
        return "AI returned an error (HTTP 404). Please try again.";
    }

    /**
     * Calls one Gemini endpoint with retry on 429.
     * Returns null if the endpoint returned 404 (caller should try next model).
     */
    private String callGeminiWithRetry(String jsonInput, String apiKey, String endpointUrl, String model) {
        for (int attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            try {
                URL url = new URL(endpointUrl + apiKey);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
                conn.setConnectTimeout(15000);
                conn.setReadTimeout(15000);
                conn.setDoOutput(true);

                try (OutputStream os = conn.getOutputStream()) {
                    os.write(jsonInput.getBytes("UTF-8"));
                }

                int responseCode = conn.getResponseCode();

                // Success — parse and return
                if (responseCode == 200) {
                    try (Scanner scanner = new Scanner(conn.getInputStream())) {
                        String responseBody = scanner.useDelimiter("\\A").next();
                        return extractTextFromGeminiResponse(responseBody);
                    }
                }

                // Rate-limited — retry after delay
                if (responseCode == 429 && attempt < MAX_RETRIES) {
                    System.out.println("⚠️ GEMINI 429 Rate Limited — retrying in 2s (attempt " + (attempt + 1) + "/" + MAX_RETRIES + ")");
                    try { Thread.sleep(RETRY_DELAY_MS); } catch (InterruptedException ignored) {}
                    continue;
                }

                // Any other error — log and fall through
                String errorBody = "";
                if (conn.getErrorStream() != null) {
                    try (Scanner s = new Scanner(conn.getErrorStream())) {
                        errorBody = s.useDelimiter("\\A").next();
                    }
                }
                System.out.println("❌ GEMINI [" + model + "] ERROR (" + responseCode + "): " + errorBody);

                // 404 = model not available on this key — signal caller to try next
                if (responseCode == 404) return null;

                // 429 exhausted retries
                if (responseCode == 429) {
                    return "AI is currently busy. Please try again in 10 seconds.";
                }

                return "AI returned an error (HTTP " + responseCode + "). Please try again.";

            } catch (Exception e) {
                e.printStackTrace();
                if (attempt == MAX_RETRIES) {
                    return null;
                }
            }
        }
        return "AI is currently busy. Please try again in 10 seconds.";
    }

    /**
     * Fully escapes a string for safe embedding inside a JSON string value.
     * Handles all control characters, Unicode line/paragraph separators,
     * and special JSON characters — preventing malformed JSON from causing
     * unexpected HTTP 404s from the Gemini API.
     * Also truncates to 4000 chars to keep prompts concise.
     */
    private String sanitizeForJson(String text) {
        if (text == null) return "";
        if (text.length() > 4000) text = text.substring(0, 4000) + "...";
        StringBuilder sb = new StringBuilder(text.length() + 64);
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            switch (c) {
                case '\\': sb.append("\\\\"); break;
                case '"':  sb.append("\\\""); break;
                case '\n': sb.append("\\n");  break;
                case '\r': sb.append("\\r");  break;
                case '\t': sb.append("\\t");  break;
                case '\b': sb.append("\\b");  break;
                case '\f': sb.append("\\f");  break;
                default:
                    // Escape all other control chars + Unicode line/paragraph separators
                    if (c < 0x20 || c == 0x2028 || c == 0x2029) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
            }
        }
        return sb.toString();
    }

    /**
     * Parses the Gemini API JSON response to extract the generated text.
     * Handles escaped quotes and newlines without a JSON library.
     */
    private String extractTextFromGeminiResponse(String json) {
        String marker1 = "\"text\": \"";
        String marker2 = "\"text\":\"";
        int start = json.indexOf(marker1);
        int markerLen = marker1.length();
        if (start < 0) {
            start = json.indexOf(marker2);
            markerLen = marker2.length();
        }
        if (start < 0) return "Could not parse AI response.";

        start += markerLen;
        StringBuilder sb = new StringBuilder();
        for (int i = start; i < json.length(); i++) {
            char c = json.charAt(i);
            if (c == '\\' && i + 1 < json.length()) {
                char next = json.charAt(i + 1);
                switch (next) {
                    case '"':  sb.append('"');  i++; break;
                    case 'n':  sb.append('\n'); i++; break;
                    case 'r':  sb.append('\r'); i++; break;
                    case 't':  sb.append('\t'); i++; break;
                    case '\\': sb.append('\\'); i++; break;
                    default:   sb.append(c);         break;
                }
            } else if (c == '"') {
                break;
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }
}

