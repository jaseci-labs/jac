# Category constants and enums for Budget Planner
# Demonstrates: enum:pub, glob:pub exports

cl {
    # Category enum - demonstrates enum:pub export
    enum:pub Category {
        INCOME,
        FOOD,
        TRANSPORT,
        UTILITIES,
        ENTERTAINMENT,
        OTHER
    }

    # Category colors - demonstrates glob:pub export
    glob:pub CATEGORY_COLORS: dict = {
        "INCOME": "#10b981",
        "FOOD": "#f59e0b",
        "TRANSPORT": "#3b82f6",
        "UTILITIES": "#8b5cf6",
        "ENTERTAINMENT": "#ec4899",
        "OTHER": "#6b7280"
    };

    # Category labels for display
    glob:pub CATEGORY_LABELS: dict = {
        "INCOME": "Income",
        "FOOD": "Food & Dining",
        "TRANSPORT": "Transport",
        "UTILITIES": "Utilities",
        "ENTERTAINMENT": "Entertainment",
        "OTHER": "Other"
    };

    # All category keys as a list
    glob:pub CATEGORIES: list = ["INCOME", "FOOD", "TRANSPORT", "UTILITIES", "ENTERTAINMENT", "OTHER"];
}
