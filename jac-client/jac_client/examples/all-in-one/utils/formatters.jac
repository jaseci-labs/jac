# Utility functions for formatting
# Demonstrates: def:pub exports, string methods
cl {
    # Format number as currency - demonstrates string methods
    def:pub formatCurrency(amount: float) -> str {
        # Use toFixed for decimal formatting
        formatted = amount.toFixed(2);
        return "$" + formatted;
    }

    # Format ISO date string to readable format
    def:pub formatDate(dateStr: str) -> str {
        date = Reflect.construct(Date, [dateStr]);
        return date.toLocaleDateString(
            "en-US", {"month": "short", "day": "numeric", "year": "numeric"}
        );
    }

    # Capitalize first letter of string
    def:pub capitalize(text: str) -> str {
        if len(text) == 0 {
            return text;
        }
        return text[0].upper() + text[1:].lower();
    }

    # Truncate string with ellipsis
    def:pub truncate(text: str, maxLength: int) -> str {
        if len(text) <= maxLength {
            return text;
        }
        return text[:maxLength] + "...";
    }

    # Format large numbers with K/M suffix
    def:pub formatCompact(num: float) -> str {
        if num >= 1000000 {
            divided = num / 1000000;
            rounded = Math.round(divided * 10) / 10;
            return (rounded.toString().concat("M"));
        }
        if num >= 1000 {
            divided = num / 1000;
            rounded = Math.round(divided * 10) / 10;
            return rounded.toString().concat("K");
        }
        return Math.round(num).toString();
    }
}
