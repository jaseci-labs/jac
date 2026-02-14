"""Test fixture for nolint comment suppression."""

def test_nolint_variations -> None {
    # This should be flagged (no nolint)
    print("error 1");

    # nolint: no-print
    print("suppressed by line before");

    print("suppressed by inline");  # nolint: no-print

    # nolint
    print("suppressed by generic nolint");

    # Multi-line print with nolint on first line
    print(  # nolint: no-print
        "multi-line message",
        "with nolint on Second line",
        "multi-line message",
        "with nolint on third line",
        "multi-line message",
        "with nolint on fifth line"
    );

    # NOLINT: NO-PRINT
    print("suppressed by uppercase nolint");

    # nolint: no-print, other-rule
    print("suppressed with multiple rules");

    # nolint: other-rule
    print("NOT suppressed - wrong rule");
}
