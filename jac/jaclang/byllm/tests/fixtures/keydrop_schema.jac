"""Fixtures for the Title-Case key-drop regression (issue #7442)."""

obj Investigation {
    has error_analysis: str = "";
    has root_cause: str = "";
}

sem Investigation.root_cause = "The identified original trigger, concretely.";

# `scores` is a genuine dict[str, V]: its keys are data, not field names.
obj TeamReport {
    has investigation: Investigation;
    has scores: dict[str, int];
}
