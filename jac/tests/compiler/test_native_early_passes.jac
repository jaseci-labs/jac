"""The kernel's early passes keep their diagnostics: validation knows which
code context a declaration lives in, and inline suppression holds."""

import from tests.support { diagnostics_text, error_codes, kernel_check_source }

test "validation preserves the client code context" {
    server = kernel_check_source(
        "def f(`from: str) -> str { return `from; }\n", "early_context.jac"
    );
    assert error_codes(server).count("E0067") == 1 , diagnostics_text(server);
    client = kernel_check_source(
        "cl {\n    def f(`from: str) -> str { return `from; }\n}\n",
        "early_context.jac"
    );
    assert "E0067" not in error_codes(client) , diagnostics_text(client);
}

test "validation diagnostics retain inline suppression" {
    for (suffix, expected) in [("", 1), (" # jac:ignore[E0052]", 0)] {
        result = kernel_check_source(
            "def missing(value) -> int { return 1; }" + suffix + "\n",
            "early_diagnostic.jac"
        );
        errors = [d for d in result.errors if d.code == "E0052"];
        assert len(errors) == expected , diagnostics_text(result);
        if errors {
            assert errors[0].span.path.endswith("early_diagnostic.jac");
            assert errors[0].span.line == 1;
        }
    }
}
