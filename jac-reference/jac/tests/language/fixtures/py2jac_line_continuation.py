"""CLI fixture for #6928: string concat across a backslash line-continuation."""

# Used to make `jac py2jac` exit 0 with empty stdout (the file was silently
# dropped). Now it must convert to valid Jac.
# `fmt: off` keeps ruff from collapsing the very construct under test.
# fmt: off
greeting = "hello " \
    "world"
# fmt: on
