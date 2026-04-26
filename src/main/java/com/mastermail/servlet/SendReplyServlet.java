package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import jakarta.mail.*;
import jakarta.mail.internet.*;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.Properties;

@WebServlet("/send-reply")
public class SendReplyServlet extends HttpServlet {
    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");

        if (user == null || !user.hasGmailLinked()) {
            response.sendRedirect("login.jsp");
            return;
        }

        // Check if this is a draft approval (forwarded from RepliesServlet)
        Boolean isDraftApproval = (Boolean) request.getAttribute("draftApproval");
        Integer draftId = (Integer) request.getAttribute("draftId");

        String recipientRaw = request.getParameter("recipient");
        String subject = request.getParameter("subject");
        String body = request.getParameter("finalMessage");

        if (body == null || body.isBlank()) {
            response.sendRedirect("emails?replyStatus=empty");
            return;
        }

        // Extract email address from "Display Name <email>" format
        String recipientEmail = extractEmail(recipientRaw);
        if (recipientEmail.isEmpty() || !recipientEmail.contains("@")) {
            System.out.println("❌ [REPLY] Invalid recipient: " + recipientRaw);
            response.sendRedirect("emails?replyStatus=invalid");
            return;
        }

        System.out.println("📤 [REPLY] Sending to: " + recipientEmail + " | Subject: " + subject + (isDraftApproval != null && isDraftApproval ? " [AUTO-DRAFT APPROVED]" : ""));

        Properties props = new Properties();
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.host", "smtp.gmail.com");
        props.put("mail.smtp.port", "587");
        props.put("mail.smtp.connectiontimeout", "10000");
        props.put("mail.smtp.timeout", "10000");

        try {
            String gmailUser = user.getGmailEmail();
            String gmailPass = user.getGmailAppPassword();

            Session mailSession = Session.getInstance(props, new Authenticator() {
                @Override
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(gmailUser, gmailPass);
                }
            });

            Message message = new MimeMessage(mailSession);
            message.setFrom(new InternetAddress(gmailUser));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(recipientEmail));
            message.setSubject(subject != null ? subject : "Re: (no subject)");
            message.setText(body);

            Transport.send(message);

            // Save the sent reply to DB for conversation history
            dao.saveReply(user.getId(), recipientEmail, recipientRaw, subject, body);

            // Mark the original email as replied if we know which one it was
            String emailIdParam = request.getParameter("emailId");
            if (emailIdParam != null && !emailIdParam.isBlank()) {
                try {
                    dao.markEmailReplied(Integer.parseInt(emailIdParam), user.getId());
                } catch (NumberFormatException ignored) {}
            }

            // If this was a draft approval, delete the draft after successful send
            if (isDraftApproval != null && isDraftApproval && draftId != null) {
                dao.deleteDraftReply(draftId, user.getId());
                System.out.println("✅ [REPLY] Auto-draft sent & deleted: draft_id=" + draftId);
                response.sendRedirect("replies?status=draftSent");
                return;
            }

            System.out.println("✅ [REPLY] Email sent successfully to: " + recipientEmail);
            response.sendRedirect("emails?replyStatus=sent");

        } catch (AuthenticationFailedException authEx) {
            System.out.println("❌ [REPLY] Gmail auth failed — check App Password");
            authEx.printStackTrace();
            String redirectUrl = (isDraftApproval != null && isDraftApproval) ? "replies?status=authfail" : "emails?replyStatus=authfail";
            response.sendRedirect(redirectUrl);
        } catch (MessagingException e) {
            System.out.println("❌ [REPLY] Failed to send: " + e.getMessage());
            e.printStackTrace();
            String redirectUrl = (isDraftApproval != null && isDraftApproval) ? "replies?status=failed" : "emails?replyStatus=failed";
            response.sendRedirect(redirectUrl);
        }
    }

    /**
     * Extracts the raw email address from various sender formats:
     *   "John Doe <john@gmail.com>" → john@gmail.com
     *   "<john@gmail.com>"          → john@gmail.com
     *   "john@gmail.com"            → john@gmail.com
     */
    private String extractEmail(String sender) {
        if (sender == null) return "";
        int start = sender.indexOf('<');
        int end = sender.indexOf('>');
        if (start >= 0 && end > start) {
            return sender.substring(start + 1, end).trim();
        }
        if (sender.contains("@")) {
            return sender.trim();
        }
        return "";
    }
}