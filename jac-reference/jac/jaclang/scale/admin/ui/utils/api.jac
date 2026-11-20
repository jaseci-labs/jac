"""API utility functions."""

# Extract error message from API response or return fallback.
def:pub getErrorMessage(
    result: dict[str, any], fallback: str = "An error occurred"
) -> str {
    if not result {
        return fallback;
    }
    err = result["error"];
    if not err {
        return fallback;
    }
    msg: str = err["message"];
    if not msg {
        return fallback;
    }
    return msg;
}
