"""Fixture: obj with optional (T | None) fields."""

obj OptionalFields {
    has maybe_int: int | None = None,
        maybe_str: str | None = None;
}
