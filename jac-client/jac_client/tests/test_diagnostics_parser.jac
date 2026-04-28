"""Tests for CompilationErrorDetector parsing of compiler error output."""

import from jac_client.plugin.src.diagnostics { BuildContext, CompilationErrorDetector }

def detect(error_output: str) -> list {
    return CompilationErrorDetector().detect(BuildContext(error_output=error_output));
}

test "structured `error[CODE]:` format: message, line, col, no help pollution" {
    diags = detect(
        "Failed to compile '/path/file.jac' for client bundle:\n"
        "error[E0025]: JavaScript arrow function syntax ('=>') is not supported in Jac\n"
        "  --> /path/file.jac:5:30\n"
        "help: Use Jac lambda syntax instead:\n"
        "    lambda e: Type { ... }"
    );
    assert len(diags) >= 1;
    msg = diags[0].message;
    assert "JavaScript arrow function syntax" in msg;
    assert "lambda syntax instead" not in msg;
    assert diags[0].line == 5 and diags[0].column == 30;
}

test "legacy `, line X, col Y:` format: message, line, col, no help pollution" {
    diags = detect(
        "Failed to compile '/path/file.jac' for client bundle:"
        "/path/file.jac, line 7, col 12: JavaScript arrow function syntax ('=>') is not supported in Jac\n"
        "help: Use Jac lambda syntax instead:\n"
        "    lambda e: Type { ... }"
    );
    assert len(diags) >= 1;
    msg = diags[0].message;
    assert "JavaScript arrow function syntax" in msg;
    assert "lambda syntax instead" not in msg;
    assert diags[0].line == 7 and diags[0].column == 12;
}
