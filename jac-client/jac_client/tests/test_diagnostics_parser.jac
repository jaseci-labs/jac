"""Unit tests for CompilationErrorDetector parsing logic.

Exercises _extract_error_detail and _parse_location_info indirectly through
CompilationErrorDetector.detect(), covering both the structured
(pretty_print) format and the legacy (str) format.
"""

import from jac_client.plugin.src.diagnostics { BuildContext, CompilationErrorDetector }

def make_ctx(error_output: str) -> BuildContext {
    return BuildContext(error_output=error_output);
}

def run_detector(error_output: str) -> list {
    ctx = make_ctx(error_output);
    detector = CompilationErrorDetector();
    return detector.detect(ctx);
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# _extract_error_detail — via detector
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "structured format: message extracted correctly" {
    output = (
        "Failed to compile '/path/file.jac' for client bundle:"
        "error[E0025]: JavaScript arrow function syntax ('=>') is not supported in Jac\n"
        "  --> /path/file.jac:5:30"
    );
    diags = run_detector(output);
    assert len(diags) >= 1 , f"Expected at least 1 diagnostic, got {len(diags)}";
    assert "JavaScript arrow function syntax" in diags[0].message , f"Got: {diags[
        0
    ].message!r}";
}

test "structured format with help text: message is not polluted by help line" {
    output = (
        "Failed to compile '/path/file.jac' for client bundle:\n"
        "error[E0025]: JavaScript arrow function syntax ('=>') is not supported in Jac\n"
        "  --> /path/file.jac:5:30\n"
        "help: Use Jac lambda syntax instead:\n"
        "    lambda e: Type { ... }\n"
        "    lambda -> None { ... }"
    );
    diags = run_detector(output);
    assert len(diags) >= 1 , f"Expected at least 1 diagnostic, got {len(diags)}";
    msg = diags[0].message;
    assert "JavaScript arrow function syntax" in msg , f"Expected real message, got: {msg!r}";
    assert "lambda syntax instead" not in msg , f"Help text leaked into message: {msg!r}";
}

test "legacy format: message extracted correctly" {
    output = (
        "Failed to compile '/path/file.jac' for client bundle:"
        "/path/file.jac, line 5, col 30: JavaScript arrow function syntax ('=>') is not supported in Jac"
    );
    diags = run_detector(output);
    assert len(diags) >= 1 , f"Expected at least 1 diagnostic, got {len(diags)}";
    assert "JavaScript arrow function syntax" in diags[0].message , f"Got: {diags[
        0
    ].message!r}";
}

test "legacy format with help text on next line: message not polluted" {
    output = (
        "Failed to compile '/path/file.jac' for client bundle:"
        "/path/file.jac, line 5, col 30: JavaScript arrow function syntax ('=>') is not supported in Jac\n"
        "help: Use Jac lambda syntax instead:\n"
        "    lambda e: Type { ... }"
    );
    diags = run_detector(output);
    assert len(diags) >= 1 , f"Expected at least 1 diagnostic, got {len(diags)}";
    msg = diags[0].message;
    assert "JavaScript arrow function syntax" in msg , f"Expected real message, got: {msg!r}";
    assert "lambda syntax instead" not in msg , f"Help text leaked into message: {msg!r}";
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# _parse_location_info — via detector
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "structured arrow format: line and col extracted" {
    output = (
        "Failed to compile '/path/file.jac' for client bundle:\n"
        "error[E0025]: some error\n"
        "  --> /path/file.jac:5:30"
    );
    diags = run_detector(output);
    assert len(diags) >= 1 , f"Expected at least 1 diagnostic, got {len(diags)}";
    assert diags[0].line == 5 , f"Expected line 5, got {diags[0].line}";
    assert diags[0].column == 30 , f"Expected col 30, got {diags[0].column}";
}

test "legacy format: line and col extracted" {
    output = (
        "Failed to compile '/path/file.jac' for client bundle:"
        "/path/file.jac, line 7, col 12: some error"
    );
    diags = run_detector(output);
    assert len(diags) >= 1 , f"Expected at least 1 diagnostic, got {len(diags)}";
    assert diags[0].line == 7 , f"Expected line 7, got {diags[0].line}";
    assert diags[0].column == 12 , f"Expected col 12, got {diags[0].column}";
}
