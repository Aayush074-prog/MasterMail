package com.mastermail.util;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Single source of truth for external configuration values.
 *
 * Resolution order (first non-blank value wins):
 *   1. OS / JVM environment variable  — GEMINI_API_KEY
 *      Preferred for production Tomcat, Docker, and CI/CD pipelines.
 *
 *   2. src/main/resources/config.properties on the classpath
 *      Used for local development. This file is listed in .gitignore
 *      and must never be committed. Copy config.example.properties to
 *      create it and fill in your key.
 *
 * If neither source provides a key the application still starts, but
 * AI features will fall back to keyword-based categorization and the
 * console will print a clear warning.
 */
public final class ConfigLoader {

    private static final String GEMINI_API_KEY;

    static {
        // ── Priority 1: environment variable ──────────────────────────────────
        String key = System.getenv("GEMINI_API_KEY");

        // ── Priority 2: config.properties on the classpath ────────────────────
        if (key == null || key.isBlank()) {
            try (InputStream in = ConfigLoader.class
                    .getClassLoader()
                    .getResourceAsStream("config.properties")) {

                if (in != null) {
                    Properties props = new Properties();
                    props.load(in);
                    key = props.getProperty("gemini.api.key", "").trim();
                }
            } catch (IOException e) {
                System.err.println("[ConfigLoader] Could not read config.properties: " + e.getMessage());
            }
        }

        GEMINI_API_KEY = (key != null && !key.isBlank()) ? key : "";

        if (GEMINI_API_KEY.isEmpty()) {
            System.err.println("[ConfigLoader] WARNING: No Gemini API key found.");
            System.err.println("[ConfigLoader]   Option A (production): set env var GEMINI_API_KEY");
            System.err.println("[ConfigLoader]   Option B (local dev):  add gemini.api.key to src/main/resources/config.properties");
        }
    }

    private ConfigLoader() {}

    /** Returns the Gemini API key, or an empty string if not configured. */
    public static String getGeminiApiKey() {
        return GEMINI_API_KEY;
    }
}
