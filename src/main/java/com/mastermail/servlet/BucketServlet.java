package com.mastermail.servlet;

import com.mastermail.dao.AdvancedDAO;
import com.mastermail.model.*;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.List;

@WebServlet("/buckets")
public class BucketServlet extends HttpServlet {
    private AdvancedDAO dao = new AdvancedDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");
        if (user != null) {
            // Get all buckets to display on the page
            List<Bucket> buckets = dao.getBuckets(user.getId());
            request.setAttribute("bucketList", buckets);
            request.getRequestDispatcher("buckets.jsp").forward(request, response);
        } else {
            response.sendRedirect("login.jsp");
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");

        if (user != null) {
            if ("createBucketAndRule".equals(action)) {
                String bName = request.getParameter("bucketName");
                String rType = request.getParameter("ruleType");
                String rValue = request.getParameter("ruleValue");

                // 1. Create the bucket and get its ID
                int newBucketId = dao.createBucketAndReturnId(user.getId(), bName);

                // 2. Add the rule to that new bucket
                if (newBucketId > 0) {
                    dao.addRule(newBucketId, rType, rValue);
                    System.out.println("✅ Bucket created: " + bName + " with rule " + rType + "=" + rValue);
                }
            } else if ("deleteBucket".equals(action)) {
                String bucketIdStr = request.getParameter("bucketId");
                if (bucketIdStr != null) {
                    int bucketId = Integer.parseInt(bucketIdStr);
                    dao.deleteBucket(bucketId, user.getId());
                }
            } else if ("addRule".equals(action)) {
                String bucketIdStr = request.getParameter("bucketId");
                String rType = request.getParameter("ruleType");
                String rValue = request.getParameter("ruleValue");
                if (bucketIdStr != null && rType != null && rValue != null && !rValue.isBlank()) {
                    dao.addRule(Integer.parseInt(bucketIdStr), rType, rValue.trim());
                    System.out.println("✅ Rule added to bucket_id=" + bucketIdStr + ": " + rType + "=" + rValue);
                }
            }
            response.sendRedirect("buckets");
        }
    }
}