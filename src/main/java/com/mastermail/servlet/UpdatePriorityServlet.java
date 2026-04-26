package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;

import java.io.IOException;
import java.util.Set;

@WebServlet("/update-priority")
public class UpdatePriorityServlet extends HttpServlet {

    private static final Set<String> VALID_PRIORITIES = Set.of(
            "needs_decision", "needs_attention", "ignored_safely");

    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        User user = session != null ? (User) session.getAttribute("user") : null;
        if (user == null) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        String emailIdParam = request.getParameter("emailId");
        String newPriority = request.getParameter("newPriority");

        if (emailIdParam == null || newPriority == null || !VALID_PRIORITIES.contains(newPriority)) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST);
            return;
        }

        int emailId;
        try {
            emailId = Integer.parseInt(emailIdParam);
        } catch (NumberFormatException e) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST);
            return;
        }

        boolean updated = dao.updateEmailCategory(emailId, user.getId(), newPriority);
        if (!updated) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        String sender = dao.getSenderByEmailId(emailId, user.getId());
        if (sender != null && !sender.isBlank()) {
            dao.saveFeedbackRule(user.getId(), sender, newPriority);
            System.out.println("[FEEDBACK] user_id=" + user.getId()
                    + " taught: \"" + sender + "\" → " + newPriority);
        }

        response.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }
}
