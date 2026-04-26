package com.mastermail.model;

public class Bucket {
    
    // 🎨 Predefined Bucket Categories for Glassmorphism Theme
    public enum BucketCategory {
        SECURITY("Security", "#ff4757", "rgba(255, 71, 87, 0.2)"),
        PERSONAL("Personal", "#3498db", "rgba(52, 152, 219, 0.2)"),
        WORK("Work", "#2ecc71", "rgba(46, 204, 113, 0.2)"),
        PROMOTIONS("Promotions", "#f39c12", "rgba(243, 156, 18, 0.2)"),
        SOCIAL("Social", "#9b59b6", "rgba(155, 89, 182, 0.2)"),
        DEFAULT("Other", "#95a5a6", "rgba(149, 165, 166, 0.2)");
        
        private String displayName;
        private String glowColor;
        private String glowAlpha;
        
        BucketCategory(String displayName, String glowColor, String glowAlpha) {
            this.displayName = displayName;
            this.glowColor = glowColor;
            this.glowAlpha = glowAlpha;
        }
        
        public String getDisplayName() { return displayName; }
        public String getGlowColor() { return glowColor; }
        public String getGlowAlpha() { return glowAlpha; }
        public String getCssClass() { return "glow-" + this.name().toLowerCase(); }
        
        public static BucketCategory fromName(String name) {
            if (name == null) return DEFAULT;
            String normalized = name.toUpperCase().replaceAll(" ", "_");
            try {
                return BucketCategory.valueOf(normalized);
            } catch (IllegalArgumentException e) {
                return DEFAULT;
            }
        }
    }
    
    private int id;
    private int userId;       // 0 = global default bucket, >0 = user-created custom bucket
    private String name;
    private String ruleType;
    private String rulePattern;
    private BucketCategory category;

    public Bucket(int id, String name) {
        this.id = id;
        this.name = name;
        this.userId = 0;
        this.category = BucketCategory.fromName(name);
    }

    public Bucket(int id, int userId, String name) {
        this.id = id;
        this.userId = userId;
        this.name = name;
        this.category = BucketCategory.fromName(name);
    }

    public Bucket(int id, String name, BucketCategory category) {
        this.id = id;
        this.name = name;
        this.userId = 0;
        this.category = (category != null) ? category : BucketCategory.fromName(name);
    }

    /** True if this is a global default bucket (Security/Personal/Work/Promotions). */
    public boolean isDefault() { return userId == 0; }

    // Getters
    public int getId() {
        return id;
    }

    public int getUserId() {
        return userId;
    }

    public String getName() {
        return name;
    }

    public String getRuleType() { 
        return ruleType; 
    }

    public String getRulePattern() { 
        return rulePattern; 
    }

    public BucketCategory getCategory() {
        return category != null ? category : BucketCategory.DEFAULT;
    }

    // Setters
    public void setId(int id) { 
        this.id = id; 
    }

    public void setName(String name) { 
        this.name = name;
        if (this.category == null) {
            this.category = BucketCategory.fromName(name);
        }
    }

    public void setRuleType(String ruleType) { 
        this.ruleType = ruleType; 
    }

    public void setRulePattern(String rulePattern) { 
        this.rulePattern = rulePattern; 
    }

    public void setCategory(BucketCategory category) { 
        this.category = category; 
    }

    public void setCategory(String categoryName) { 
        this.category = BucketCategory.fromName(categoryName); 
    }
}