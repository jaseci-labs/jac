"""Fixtures for the Title-Case key-drop regression (issue #7442)."""

obj Investigation {
    has error_analysis: str = "",
        root_cause: str = "";
}

sem Investigation.root_cause = "The identified original trigger, concretely.";

# `scores` is a genuine dict[str, V]: its keys are data, not field names.
obj TeamReport {
    has investigation: Investigation,
        scores: dict[str, int];
}

# `Optional[T]` has one structural arm (safe to repair); an `Optional[dict]`
# arm's keys are real data and must survive.
obj OptHolder {
    has investigation: Investigation | None = None,
        scores: dict[str, int] | None = None;
}

# Distinct-field dataclasses whose union is repaired against the best-match arm.
obj Dog {
    has name: str = "",
        breed: str = "";
}

obj Cat {
    has name: str = "",
        color: str = "";
}

obj PetHolder {
    has pet: Dog | Cat;
}

# A dict arm makes the union ambiguous, so its keys are left untouched.
obj DictArmHolder {
    has payload: Investigation | dict[str, int];
}
