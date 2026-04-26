package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import com.mastermail.util.MailConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;

@WebServlet("/auth")
public class AuthServlet extends HttpServlet {
    private AdvancedDAO dao = new AdvancedDAO();

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");

        if ("register".equals(action)) {
            String name = request.getParameter("name");
            String email = request.getParameter("email");
            String pass = request.getParameter("pass");

            // Reject duplicate emails before spending an OTP send
            if (dao.emailExists(email)) {
                response.sendRedirect("register.jsp?error=5");
                return;
            }

            // Generate OTP and send verification email
            String otp = MailConfig.generateOTP();
            boolean sent = MailConfig.sendOtpEmail(email, name, otp);

            if (sent) {
                // Store pending registration in session
                HttpSession session = request.getSession();
                session.setAttribute("pendingName", name);
                session.setAttribute("pendingEmail", email);
                session.setAttribute("pendingPass", pass);
                session.setAttribute("pendingOtp", otp);
                session.setAttribute("otpTimestamp", System.currentTimeMillis());
                session.setAttribute("otpAttempts", 0);
                session.setAttribute("resendCount", 0);

                response.sendRedirect("verify-otp.jsp");
            } else {
                response.sendRedirect("register.jsp?error=2");
            }
        }
        else if ("verify-otp".equals(action)) {
            HttpSession session = request.getSession();
            String pendingOtp = (String) session.getAttribute("pendingOtp");
            String submittedOtp = request.getParameter("otp");
            Long otpTimestamp = (Long) session.getAttribute("otpTimestamp");
            Integer attempts = (Integer) session.getAttribute("otpAttempts");

            if (pendingOtp == null || otpTimestamp == null) {
                // No pending registration — go back to register
                response.sendRedirect("register.jsp");
                return;
            }

            // Check expiry (5 minutes)
            if (System.currentTimeMillis() - otpTimestamp > 5 * 60 * 1000) {
                clearPendingRegistration(session);
                response.sendRedirect("register.jsp?error=3");
                return;
            }

            // Check max attempts (5)
            if (attempts != null && attempts >= 5) {
                clearPendingRegistration(session);
                response.sendRedirect("register.jsp?error=4");
                return;
            }

            if (pendingOtp.equals(submittedOtp)) {
                // OTP correct — create the account
                String name = (String) session.getAttribute("pendingName");
                String email = (String) session.getAttribute("pendingEmail");
                String pass = (String) session.getAttribute("pendingPass");

                boolean registered = dao.registerUser(name, email, pass);
                clearPendingRegistration(session);

                if (registered) {
                    response.sendRedirect("login.jsp?msg=success");
                } else {
                    response.sendRedirect("register.jsp?error=1");
                }
            } else {
                // Wrong OTP
                session.setAttribute("otpAttempts", (attempts != null ? attempts : 0) + 1);
                response.sendRedirect("verify-otp.jsp?error=1");
            }
        }
        else if ("resend-otp".equals(action)) {
            HttpSession session = request.getSession();
            Integer resendCount = (Integer) session.getAttribute("resendCount");
            String email = (String) session.getAttribute("pendingEmail");
            String name = (String) session.getAttribute("pendingName");

            if (email == null) {
                response.sendRedirect("register.jsp");
                return;
            }

            // Max 3 resends
            if (resendCount != null && resendCount >= 3) {
                response.sendRedirect("verify-otp.jsp?error=2");
                return;
            }

            // Generate new OTP and resend
            String newOtp = MailConfig.generateOTP();
            boolean sent = MailConfig.sendOtpEmail(email, name, newOtp);

            if (sent) {
                session.setAttribute("pendingOtp", newOtp);
                session.setAttribute("otpTimestamp", System.currentTimeMillis());
                session.setAttribute("otpAttempts", 0);
                session.setAttribute("resendCount", (resendCount != null ? resendCount : 0) + 1);
                response.sendRedirect("verify-otp.jsp?msg=resent");
            } else {
                response.sendRedirect("verify-otp.jsp?error=3");
            }
        }
        else if ("forgot-password".equals(action)) {
            String email = request.getParameter("email");
            if (email == null || email.isBlank()) {
                response.sendRedirect("forgot-password.jsp?error=1");
                return;
            }
            if (!dao.emailExists(email.trim())) {
                response.sendRedirect("forgot-password.jsp?error=2");
                return;
            }
            String otp = MailConfig.generateOTP();
            boolean sent = MailConfig.sendOtpEmail(email.trim(), "User", otp);
            if (!sent) {
                response.sendRedirect("forgot-password.jsp?error=3");
                return;
            }
            HttpSession session = request.getSession();
            session.setAttribute("fpEmail", email.trim());
            session.setAttribute("fpOtp", otp);
            session.setAttribute("fpTimestamp", System.currentTimeMillis());
            session.setAttribute("fpAttempts", 0);
            response.sendRedirect("forgot-password-otp.jsp");
        }
        else if ("fp-verify-otp".equals(action)) {
            HttpSession session = request.getSession();
            String fpOtp = (String) session.getAttribute("fpOtp");
            Long fpTimestamp = (Long) session.getAttribute("fpTimestamp");
            Integer fpAttempts = (Integer) session.getAttribute("fpAttempts");
            String submitted = request.getParameter("otp");

            if (fpOtp == null || fpTimestamp == null) {
                response.sendRedirect("forgot-password.jsp");
                return;
            }
            if (System.currentTimeMillis() - fpTimestamp > 5 * 60 * 1000) {
                clearFpSession(session);
                response.sendRedirect("forgot-password.jsp?error=4");
                return;
            }
            if (fpAttempts != null && fpAttempts >= 5) {
                clearFpSession(session);
                response.sendRedirect("forgot-password.jsp?error=5");
                return;
            }
            if (fpOtp.equals(submitted)) {
                session.setAttribute("fpVerified", true);
                response.sendRedirect("reset-password.jsp");
            } else {
                session.setAttribute("fpAttempts", (fpAttempts != null ? fpAttempts : 0) + 1);
                response.sendRedirect("forgot-password-otp.jsp?error=1");
            }
        }
        else if ("reset-password".equals(action)) {
            HttpSession session = request.getSession();
            Boolean verified = (Boolean) session.getAttribute("fpVerified");
            String fpEmail = (String) session.getAttribute("fpEmail");
            if (verified == null || !verified || fpEmail == null) {
                response.sendRedirect("forgot-password.jsp");
                return;
            }
            String newPass = request.getParameter("pass");
            String confirmPass = request.getParameter("confirmPass");
            if (newPass == null || newPass.isBlank() || !newPass.equals(confirmPass)) {
                response.sendRedirect("reset-password.jsp?error=1");
                return;
            }
            dao.updatePassword(fpEmail, newPass);
            clearFpSession(session);
            response.sendRedirect("login.jsp?msg=reset");
        }
        else if ("login".equals(action)) {
            String email = request.getParameter("email");
            String pass = request.getParameter("pass");
            User user = dao.loginUser(email, pass);
            if (user != null) {
                // CRITICAL: Invalidate any existing session first.
                // This prevents session bleed if another user was logged in
                // on the same browser (same JSESSIONID cookie).
                HttpSession oldSession = request.getSession(false);
                if (oldSession != null) {
                    oldSession.invalidate();
                }
                // Create a brand-new session for this user
                HttpSession session = request.getSession(true);
                session.setAttribute("user", user);
                session.setMaxInactiveInterval(30 * 60); // 30 min timeout

                System.out.println("[LOGIN] New session created for: " + user.getEmail()
                        + " | user_id=" + user.getId()
                        + " | session=" + session.getId());

                if (user.isAdmin()) {
                    response.sendRedirect("admin");
                } else {
                    response.sendRedirect("emails");
                }
            } else {
                response.sendRedirect("login.jsp?error=1");
            }
        }
    }

    private void clearFpSession(HttpSession session) {
        session.removeAttribute("fpEmail");
        session.removeAttribute("fpOtp");
        session.removeAttribute("fpTimestamp");
        session.removeAttribute("fpAttempts");
        session.removeAttribute("fpVerified");
    }

    private void clearPendingRegistration(HttpSession session) {
        session.removeAttribute("pendingName");
        session.removeAttribute("pendingEmail");
        session.removeAttribute("pendingPass");
        session.removeAttribute("pendingOtp");
        session.removeAttribute("otpTimestamp");
        session.removeAttribute("otpAttempts");
        session.removeAttribute("resendCount");
    }
}