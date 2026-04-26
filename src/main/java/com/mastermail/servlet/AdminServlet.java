package com.mastermail.servlet;

import com.mastermail.dao.AdminDAO;
import com.mastermail.model.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;

import java.io.IOException;
import java.util.List;

/**
 * Admin Command Center — accessible only to users with role = 'ADMIN'.
 * The companion AdminFilter blocks all non-admin requests to /admin
 * before they even reach this servlet.
 */
@WebServlet("/admin")
public class AdminServlet extends HttpServlet {

    private final AdminDAO adminDAO = new AdminDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("user") : null;

        // Double-check (filter should have caught this already)
        if (user == null || !user.isAdmin()) {
            response.sendRedirect("login.jsp");
            return;
        }

        // Load statistics
        request.setAttribute("totalUsers", adminDAO.getTotalUsersCount());
        request.setAttribute("activeUsers", adminDAO.getActiveUsersCount());
        request.setAttribute("totalEmails", adminDAO.getTotalEmailsCount());

        // Load user table
        List<User> allUsers = adminDAO.getAllUsers();
        request.setAttribute("allUsers", allUsers);

        request.getRequestDispatcher("admin.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("user") : null;

        if (user == null || !user.isAdmin()) {
            response.sendRedirect("login.jsp");
            return;
        }

        String action = request.getParameter("action");

        if ("deleteUser".equals(action)) {
            String userIdStr = request.getParameter("userId");
            if (userIdStr != null) {
                int targetId = Integer.parseInt(userIdStr);
                // Prevent an admin from deleting themselves
                if (targetId == user.getId()) {
                    request.setAttribute("adminMsg", "⚠️ You cannot delete your own admin account.");
                } else {
                    boolean ok = adminDAO.deleteUser(targetId);
                    request.setAttribute("adminMsg", ok
                            ? "✅ User #" + targetId + " and all associated data deleted."
                            : "❌ Failed to delete user #" + targetId + ". Check server logs.");
                }
            }
        }

        // Re-render the dashboard after the action
        doGet(request, response);
    }
}


