"""Utility helpers — empty-input guards and result extraction."""

def _empty(tool_name: str, msg: str) -> dict {
    return {"ok": False, "tool": tool_name, "data": {}, "error": {"message": msg}};
}

def:pub empty_code_response(tool_name: str) -> dict {
    return _empty(tool_name, "Code cannot be empty.");
}

def:pub empty_error_message_response -> dict {
    return _empty("explain_error", "Error message cannot be empty.");
}

def:pub empty_name_response -> dict {
    return _empty("get_example", "Example name cannot be empty.");
}

def:pub empty_query_response -> dict {
    return _empty("search_docs", "Search query cannot be empty.");
}

def:pub extract_first_error(result: dict) -> str {
    try {
        return result["data"]["errors"][0]["message"];
    } except Exception {
        return "";
    }
}
