package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.*;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.List;

@WebServlet("/advanced")
public class AdvancedServlet extends HttpServlet {
    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");
        if (user != null) {
            request.setAttribute("inboxEmails", dao.getEmails(user.getId()));
            request.setAttribute("trashEmails", dao.getDeletedEmails(user.getId()));
            // Member 4: Add OTP detection results
            request.setAttribute("otpList", dao.detectOTPs(user.getId()));

            request.getRequestDispatcher("advanced.jsp").forward(request, response);
        } else {
            response.sendRedirect("login.jsp");
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        String emailIdStr = request.getParameter("emailId");

        if ("safeDelete".equals(action)) {
            dao.safeDelete(Integer.parseInt(emailIdStr));
        } else if ("restore".equals(action)) {
            dao.restoreEmail(Integer.parseInt(emailIdStr));
        }

        // Refresh the lists after any action
        doGet(request, response);
    }
}