def _enforce_check(result: str, file_path: str) -> str {
    if "Error:" in result
    and (
        "Permission denied" in result
        or "File not found" in result
        or "old_string not found" in result
    ) {
        return result;
    }

    if not file_path.endswith(".jac") {
        return result;
    }

    if "VALIDATION ERRORS" in result {
        return result + "\n\n[ACTION REQUIRED: Call jac_docs(query) to look up the correct Jac syntax BEFORE attempting to fix. Do NOT guess — look it up first, then fix.]";
    }

    if "RUNTIME ERRORS" in result {
        return result + "\n\n[ACTION REQUIRED: Call jac_docs(query) to look up the correct Jac syntax BEFORE attempting to fix. Do NOT guess — look it up first, then fix.]";
    }

    return result;
}


impl write_code(file_path: str, content: str) -> str {
    loop_msg = check_tool_loop("write_code", file_path);
    if loop_msg {
        return loop_msg;
    }
    result = write_file_guarded(file_path, content);
    return _enforce_check(result, file_path);
}


impl edit_code(
    file_path: str, old_string: str, new_string: str, replace_all: bool = False
) -> str {
    loop_msg = check_tool_loop("edit_code", file_path + "::" + old_string[:50]);
    if loop_msg {
        return loop_msg;
    }
    result = edit_file_guarded(file_path, old_string, new_string, replace_all);
    return _enforce_check(result, file_path);
}
