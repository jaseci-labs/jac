"""API utility functions."""

cl {
    # Extract error message from API response or return fallback.
    def:pub getErrorMessage(result: dict, fallback: str = "An error occurred") -> str {
        return (result and result["error"] and result["error"]["message"]) or fallback;
    }
}
