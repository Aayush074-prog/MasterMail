package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.*;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@WebServlet("/emails")
public class EmailServlet extends HttpServlet {
    private static final int PAGE_SIZE = 25;
    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");

        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }

        System.out.println("[EMAILS-GET] user_id=" + user.getId()
                + " | email=" + user.getEmail()
                + " | session=" + session.getId()
                + " | gmail_linked=" + user.hasGmailLinked());

        String action = request.getParameter("action");

        // Sync Gmail using the USER'S OWN credentials
        if ("sync".equals(action)) {
            if (!user.hasGmailLinked()) {
                request.setAttribute("syncResult",
                        "⚠️ Please link your Gmail account first — enter your Gmail & App Password below.");
            } else {
                System.out.println("========================================");
                System.out.println("📩 SYNC TRIGGERED for user_id: " + user.getId()
                        + " | gmail: " + user.getGmailEmail());
                System.out.println("========================================");

                int synced = dao.syncGmail(user.getId(), user.getGmailEmail(), user.getGmailAppPassword());

                request.setAttribute("syncResult", synced >= 0
                        ? "✅ Sync complete — " + synced + " new email(s) imported."
                        : "❌ Sync failed — check your Gmail / App Password in settings below.");

                System.out.println("📩 SYNC FINISHED — result: " + synced);
            }
        }

        // Parse page param
        int page = 1;
        String pageParam = request.getParameter("page");
        if (pageParam != null) {
            try { page = Math.max(1, Integer.parseInt(pageParam)); } catch (NumberFormatException ignored) {}
        }

        int totalCount = dao.countEmails(user.getId());
        int totalPages = (totalCount == 0) ? 1 : (int) Math.ceil((double) totalCount / PAGE_SIZE);
        if (page > totalPages) page = totalPages;

        List<Email> emailList = dao.getEmailsPage(user.getId(), page, PAGE_SIZE);
        System.out.println("📬 Inbox page " + page + "/" + totalPages + " — " + emailList.size() + " email(s) for user_id " + user.getId());

        request.setAttribute("emailList", emailList);
        request.setAttribute("currentPage", page);
        request.setAttribute("totalPages", totalPages);
        request.setAttribute("totalCount", totalCount);
        List<String> freshOTPs = new ArrayList<>(dao.getFreshOTPs(user.getId()));
        @SuppressWarnings("unchecked")
        Set<String> dismissed = (Set<String>) session.getAttribute("dismissedOTPs");
        if (dismissed != null) freshOTPs.removeIf(dismissed::contains);
        request.setAttribute("freshOTPs", freshOTPs);

        request.getRequestDispatcher("inbox.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");
        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }

        String action = request.getParameter("action");

        if ("saveGmail".equals(action)) {
            // Save Gmail credentials
            String gmailEmail = request.getParameter("gmailEmail");
            String appPassword = request.getParameter("appPassword");

            if (gmailEmail != null && !gmailEmail.isBlank()
                    && appPassword != null && !appPassword.isBlank()) {
                boolean saved = dao.saveGmailCredentials(user.getId(), gmailEmail.trim(), appPassword.trim());
                if (saved) {
                    // Update the session object so sync works immediately
                    user.setGmailEmail(gmailEmail.trim());
                    user.setGmailAppPassword(appPassword.trim());
                    session.setAttribute("user", user);
                }
            }
            response.sendRedirect("emails");
        } else {
            // Legacy: add local email
            dao.addEmail(user.getId(), request.getParameter("sender"),
                    request.getParameter("subject"), request.getParameter("body"));
            response.sendRedirect("emails");
        }
    }
}