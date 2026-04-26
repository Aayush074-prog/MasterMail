package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.List;

@WebServlet("/replies")
public class RepliesServlet extends HttpServlet {
    private final AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");

        if (user == null) {
            response.sendRedirect("login.jsp");
            return;
        }

        String viewThread = request.getParameter("thread");

        if (viewThread != null && !viewThread.isBlank()) {
            // Load full conversation with a specific recipient
            List<String[]> conversation = dao.getConversation(user.getId(), viewThread);
            request.setAttribute("conversation", conversation);
            request.setAttribute("threadEmail", viewThread);

            // Find the display name from the threads list
            List<String[]> threads = dao.getReplyThreads(user.getId());
            String threadName = viewThread;
            for (String[] t : threads) {
                if (viewThread.equals(t[0]) && t[1] != null && !t[1].isEmpty()) {
                    threadName = t[1];
                    break;
                }
            }
            request.setAttribute("threadName", threadName);
        }

        // Always load thread list for the sidebar/list view
        List<String[]> threads = dao.getReplyThreads(user.getId());
        request.setAttribute("replyThreads", threads);

        // Load auto-drafted replies awaiting approval and the rules that generate them
        List<String[]> autoDrafts = dao.getAutoDraftedReplies(user.getId());
        List<String[]> autoRules = dao.getAutoReplyRules(user.getId());
        request.setAttribute("autoDrafts", autoDrafts);
        request.setAttribute("autoReplyRules", autoRules);

        System.out.println("[REPLIES] Loaded " + threads.size() + " thread(s), " + autoDrafts.size() + " auto-draft(s), " + autoRules.size() + " rule(s) for user_id=" + user.getId());

        request.getRequestDispatcher("replies.jsp").forward(request, response);
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

        if ("approveDraft".equals(action)) {
            // Approve and send a drafted reply
            try {
                int draftId = Integer.parseInt(request.getParameter("draftId"));
                String recipient = request.getParameter("recipient");
                String subject = request.getParameter("subject");
                String message = request.getParameter("message");

                // Send the email via SendReplyServlet logic (redirect to send-reply)
                request.setAttribute("draftApproval", true);
                request.setAttribute("recipient", recipient);
                request.setAttribute("subject", subject);
                request.setAttribute("finalMessage", message);
                request.setAttribute("draftId", draftId);

                // Forward to send-reply servlet to actually send it
                request.getRequestDispatcher("send-reply").forward(request, response);
                return;

            } catch (NumberFormatException e) {
                // Invalid draft ID
            }
        } else if ("deleteDraft".equals(action)) {
            // Delete a draft without sending
            try {
                int draftId = Integer.parseInt(request.getParameter("draftId"));
                dao.deleteDraftReply(draftId, user.getId());
            } catch (NumberFormatException e) {
                // Invalid draft ID
            }
        }

        response.sendRedirect("replies");
    }
}

