package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.List;

@WebServlet("/auto-reply")
public class AutoReplyServlet extends HttpServlet {
    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");
        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }
        response.sendRedirect("replies");
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

        switch (action != null ? action : "") {
            case "addRule":
                String keyword = request.getParameter("keyword");
                String replyMessage = request.getParameter("replyMessage");
                if (keyword != null && !keyword.isBlank() && replyMessage != null && !replyMessage.isBlank()) {
                    dao.addAutoReplyRule(user.getId(), keyword, replyMessage);
                }
                break;

            case "deleteRule":
                try {
                    int ruleId = Integer.parseInt(request.getParameter("ruleId"));
                    dao.deleteAutoReplyRule(ruleId, user.getId());
                } catch (NumberFormatException e) {
                    // Invalid rule ID
                }
                break;

            case "toggleRule":
                try {
                    int ruleId = Integer.parseInt(request.getParameter("ruleId"));
                    dao.toggleAutoReplyRule(ruleId, user.getId());
                } catch (NumberFormatException e) {
                    // Invalid rule ID
                }
                break;

            case "deleteDraft":
                try {
                    int draftId = Integer.parseInt(request.getParameter("draftId"));
                    dao.deleteDraftReply(draftId, user.getId());
                } catch (NumberFormatException e) {
                    // Invalid draft ID
                }
                break;

            default:
                break;
        }

        response.sendRedirect("replies");
    }
}
