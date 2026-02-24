"""Type narrowing tests.

Tests CFG-based type narrowing with affected_symbols optimization.
"""

import from pathlib { Path }
import from subprocess { run, PIPE }
import from tempfile { NamedTemporaryFile }
import from os { unlink }

glob FIXTURES_DIR = Path(__file__).parent / "fixtures";

"""Test that accessing attributes on None in else branch reports errors."""
test "type narrowing detects None attribute errors" {
    fixture = FIXTURES_DIR / "type_narrowing_errors.jac";

    # Run jac check on the fixture
    result = run(
        ["jac", "check", str(fixture)],
        capture_output=True,
        text=True
    );

    # Should have errors (non-zero exit code)
    assert result.returncode != 0, "Expected errors but jac check passed";

    # Check for specific error patterns
    output = result.stdout + result.stderr;
    has_narrowing_error = "NoneType" in output or "has no attribute" in output;
    assert has_narrowing_error, f"Expected type narrowing errors, got: {output}";
}

"""Test that valid operations in narrowed branches compile without errors."""
test "type narrowing allows valid operations" {
    code = '''
def valid_narrowing(value: int | str | None) -> str {
    if value is not None {
        if isinstance(value, int) {
            return str(value * 2);
        } else {
            return value.upper();
        }
    }
    return "none";
}
''';

    # Write to temp file
    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
        f.write(code);
        temp_path = f.name;
    }

    try {
        result = run(
            ["jac", "check", temp_path],
            capture_output=True,
            text=True
        );

        # Should pass without errors
        err_output = result.stdout + result.stderr;
        assert result.returncode == 0, f"Expected no errors for valid code, got: {err_output}";
    } finally {
        unlink(temp_path);
    }
}

"""Test that affected_symbols optimization handles many if statements efficiently."""
test "affected_symbols optimization handles complex control flow" {
    code = '''
def many_ifs(x: int | str, y: int | None) {
    a = 0;
    if y is not None { a = 1; }
    if y is not None { a = 2; }
    if y is not None { a = 3; }
    if y is not None { a = 4; }
    if y is not None { a = 5; }
    if y is not None { a = 6; }
    print(x, a);
}
''';

    with NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f {
        f.write(code);
        temp_path = f.name;
    }

    try {
        result = run(
            ["jac", "check", temp_path],
            capture_output=True,
            text=True,
            timeout=30  # Should complete quickly with optimization
        );

        # Should compile without errors
        err_output = result.stdout + result.stderr;
        assert result.returncode == 0, f"Expected no errors, got: {err_output}";
    } finally {
        unlink(temp_path);
    }
}
