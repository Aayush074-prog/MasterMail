package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;

import java.io.IOException;

@WebServlet("/resolve-alert")
public class ResolveAlertServlet extends HttpServlet {

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

        String findingKey = request.getParameter("findingKey");
        if (findingKey == null || findingKey.isBlank()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST);
            return;
        }

        dao.markFindingResolved(user.getId(), findingKey);
        System.out.println("[SECURITY] user_id=" + user.getId() + " resolved: " + findingKey);
        response.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }
}
