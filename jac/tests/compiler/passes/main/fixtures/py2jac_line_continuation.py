"""Fixture for #6928: implicit string concat across a backslash line-continuation."""

# The reported minimal repro: two adjacent string literals joined by an explicit
# `\` line-continuation. CPython folds these into a single str constant; py2jac
# used to leak the source `\` into the emitted Jac, producing unparsable output.
# `fmt: off` keeps ruff from collapsing the very construct under test.
# fmt: off
basic = "abc" \
    "def"

# Real-world llvmlite ir/instructions.py pattern: a continued segment that also
# carries a trailing `\n` escape, which must survive the fold intact.
fmt = "line one " \
      "line two\n"
# fmt: on
