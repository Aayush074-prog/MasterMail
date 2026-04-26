package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.HashSet;
import java.util.Set;

@WebServlet("/dismiss-otp")
public class DismissOtpServlet extends HttpServlet {
    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null) { response.setStatus(HttpServletResponse.SC_NO_CONTENT); return; }

        User user = (User) session.getAttribute("user");
        if (user == null) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); return; }

        String otpKey = request.getParameter("otpKey");
        if (otpKey != null && !otpKey.isBlank()) {
            // 1. Delete from DB so sync cannot re-surface this OTP
            dao.deleteOtpByKey(user.getId(), otpKey);

            // 2. Also track in session as a safety net for the current page load cycle
            @SuppressWarnings("unchecked")
            Set<String> dismissed = (Set<String>) session.getAttribute("dismissedOTPs");
            if (dismissed == null) {
                dismissed = new HashSet<>();
                session.setAttribute("dismissedOTPs", dismissed);
            }
            dismissed.add(otpKey);
        }
        response.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }
}
