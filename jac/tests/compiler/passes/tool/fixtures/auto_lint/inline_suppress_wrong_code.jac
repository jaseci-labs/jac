"""Fixture: a jac:ignore code that does not match the rule must NOT suppress it.

The print() on line 4 carries `# jac:ignore[W3001]` (staticmethod-to-static),
which is unrelated to the no-print rule (E3012). The no-print error must still
fire on that line; inline suppression only applies to the code(s) it names.
"""

def greet(name: str) -> None {
    print("still flagged");  # jac:ignore[W3001]
}
