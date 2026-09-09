"""Shared helper reached by all three apps.

The `== None` comparison is a deliberate W2058: `jac check` compiles this
module once per app that reaches it, so the warning shows up under each
app's `[<app>]` prefix.
"""

def label(count: int | None = None) -> str {
    if count == None {
        return "none";
    }
    return f"{count} item(s)";
}
