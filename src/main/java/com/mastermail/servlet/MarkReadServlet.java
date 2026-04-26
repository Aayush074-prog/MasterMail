package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;

@WebServlet("/mark-read")
public class MarkReadServlet extends HttpServlet {
    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("user") : null;
        if (user == null) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        String emailIdParam = request.getParameter("emailId");
        if (emailIdParam != null && !emailIdParam.isBlank()) {
            try {
                int emailId = Integer.parseInt(emailIdParam);

                // Step 1: Update MySQL — always do this first
                dao.markEmailRead(emailId, user.getId());

                // Step 2: IMAP write-back in a background thread so IMAP latency
                // (~500ms–2s) does not block this AJAX response. The client already
                // updated the UI optimistically before the response returns.
                if (user.hasGmailLinked()) {
                    String messageId = dao.getMessageIdByEmailId(emailId, user.getId());
                    if (messageId != null) {
                        final String mid     = messageId;
                        final String gmail   = user.getGmailEmail();
                        final String appPass = user.getGmailAppPassword();
                        new Thread(() -> dao.setGmailMessageSeen(gmail, appPass, mid),
                                   "imap-seen-" + emailId).start();
                    }
                }

            } catch (NumberFormatException ignored) {}
        }

        response.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }
}
