"""Shared tuple-valued table, like the compiler's binary operator map."""
glob OPERATOR_NAMES: dict[str, tuple[str, str]] = {"+": ("add", "radd")};
