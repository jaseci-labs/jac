"""Fixture for a ternary expression as a call target."""

def pick(a, b, c):
    return (a if c else b)(10)
