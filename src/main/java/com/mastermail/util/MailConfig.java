package com.mastermail.util;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.security.SecureRandom;
import java.util.Properties;

/**
 * Centralized mail configuration & OTP sender for MasterMail.ai.
 * Uses Gmail SMTP with App Password for sending verification emails.
 */
public class MailConfig {

    // Shared Gmail credentials (same account used for IMAP sync)
    public static final String SMTP_EMAIL = "aayush.das@mitwpu.edu.in";
    public static final String SMTP_APP_PASSWORD = "ajwd wrcz vaqa aeit";

    private static final SecureRandom random = new SecureRandom();

    /** Generates a cryptographically secure 6-digit OTP. */
    public static String generateOTP() {
        int otp = 100000 + random.nextInt(900000);
        return String.valueOf(otp);
    }

    /**
     * Sends an OTP verification email to the given address.
     * @return true if sent successfully, false on failure.
     */
    public static boolean sendOtpEmail(String toEmail, String userName, String otp) {
        Properties props = new Properties();
        props.put("mail.smtp.host", "smtp.gmail.com");
        props.put("mail.smtp.port", "587");
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.connectiontimeout", "10000");
        props.put("mail.smtp.timeout", "10000");

        Session session = Session.getInstance(props, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(SMTP_EMAIL, SMTP_APP_PASSWORD);
            }
        });

        try {
            MimeMessage message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SMTP_EMAIL, "MasterMail.ai"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            message.setSubject("Your MasterMail Verification Code: " + otp);

            String htmlBody = """
                <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto;
                            background: linear-gradient(135deg, #0f172a, #1e293b); border-radius: 16px;
                            padding: 40px; color: white;">
                    <h1 style="color: #6f42c1; font-size: 24px; margin: 0 0 8px 0;">MasterMail.ai</h1>
                    <p style="color: #94a3b8; font-size: 14px; margin: 0 0 30px 0;">Email Verification</p>

                    <p style="font-size: 16px; margin: 0 0 20px 0;">Hi <strong>%s</strong>,</p>
                    <p style="color: #94a3b8; font-size: 14px; margin: 0 0 25px 0;">
                        Use the code below to verify your email and complete your registration:
                    </p>

                    <div style="background: rgba(111, 66, 193, 0.15); border: 1px solid rgba(111, 66, 193, 0.3);
                                border-radius: 12px; padding: 20px; text-align: center; margin: 0 0 25px 0;">
                        <span style="font-size: 36px; font-weight: 700; letter-spacing: 8px; color: #8559da;">%s</span>
                    </div>

                    <p style="color: #94a3b8; font-size: 13px; margin: 0 0 5px 0;">
                        ⏱ This code expires in <strong style="color: white;">5 minutes</strong>.
                    </p>
                    <p style="color: #94a3b8; font-size: 13px; margin: 0;">
                        If you didn't request this, you can safely ignore this email.
                    </p>
                </div>
                """.formatted(userName, otp);

            message.setContent(htmlBody, "text/html; charset=UTF-8");
            Transport.send(message);

            System.out.println("[OTP] Verification email sent to " + toEmail);
            return true;

        } catch (AuthenticationFailedException e) {
            System.out.println("[OTP] ❌ SMTP AUTH FAILED for " + SMTP_EMAIL + " — App Password is expired or invalid. Generate a new one at myaccount.google.com → Security → App passwords.");
            e.printStackTrace();
            return false;
        } catch (Exception e) {
            System.out.println("[OTP] ❌ FAILED to send to " + toEmail + ": " + e.getClass().getSimpleName() + " — " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /** Masks an email for display: aayush.das@mitwpu.edu.in → aa****as@mitwpu.edu.in */
    public static String maskEmail(String email) {
        if (email == null || !email.contains("@")) return email;
        String[] parts = email.split("@");
        String local = parts[0];
        if (local.length() <= 3) return local.charAt(0) + "***@" + parts[1];
        return local.substring(0, 2) + "****" + local.substring(local.length() - 2) + "@" + parts[1];
    }
}

