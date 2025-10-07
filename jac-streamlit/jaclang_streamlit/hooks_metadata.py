"""Hook metadata for jaclang-streamlit plugin."""


def get_hooks() -> list[str]:
    """Return list of hooks implemented by this plugin."""
    return ["create_cmd"]
