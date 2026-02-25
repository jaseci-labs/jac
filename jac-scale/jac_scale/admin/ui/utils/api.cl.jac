"""API utility functions."""

cl {
    def:pub getErrorMessage(result: dict, fallback: str = "An error occurred") -> str {
        """Extract error message from API response or return fallback."""
        return (result and result["error"] and result["error"]["message"]) or fallback;
    }
}
