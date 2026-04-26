package com.mastermail.filter;

import com.mastermail.model.User;
import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.*;

import java.io.IOException;

/**
 * Security gate for the Admin Command Center.
 * Intercepts every request to /admin and /admin/* and ensures
 * only authenticated users with role = 'ADMIN' can pass through.
 * Everyone else is kicked back to login.jsp.
 */
@WebFilter(urlPatterns = {"/admin", "/admin/*"})
public class AdminFilter implements Filter {

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse,
                         FilterChain chain) throws IOException, ServletException {

        HttpServletRequest request = (HttpServletRequest) servletRequest;
        HttpServletResponse response = (HttpServletResponse) servletResponse;

        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("user") : null;

        if (user == null) {
            // Not logged in at all — redirect to login
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        if (!user.isAdmin()) {
            // Logged in but not an admin — redirect to inbox with subtle warning
            System.out.println("⛔ [ADMIN FILTER] Non-admin user '" + user.getEmail()
                    + "' (role=" + user.getRole() + ") attempted to access " + request.getRequestURI());
            response.sendRedirect(request.getContextPath() + "/emails");
            return;
        }

        // Admin verified — let the request through
        chain.doFilter(servletRequest, servletResponse);
    }
}

