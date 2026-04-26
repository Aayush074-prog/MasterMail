package com.mastermail.model;

public class Email {
    private int id;
    private String sender, subject, body, category, date, bucketName;
    private boolean isRead, isReplied;

    public Email(int id, String sender, String subject, String body, String category, String date, String bucketName) {
        this(id, sender, subject, body, category, date, bucketName, false, false);
    }

    public Email(int id, String sender, String subject, String body, String category, String date, String bucketName, boolean isRead, boolean isReplied) {
        this.id = id;
        this.sender = sender;
        this.subject = subject;
        this.body = body;
        this.category = category;
        this.date = date;
        this.bucketName = bucketName;
        this.isRead = isRead;
        this.isReplied = isReplied;
    }

    public String getBucketName() {
        return bucketName != null ? bucketName : "Inbox";
    }

    public int getId() { return id; }
    public String getSender() { return sender; }
    public String getSubject() { return subject; }
    public String getBody() { return body; }
    public String getCategory() { return category; }
    public String getDate() { return date; }
    public boolean isRead() { return isRead; }
    public boolean isReplied() { return isReplied; }
}