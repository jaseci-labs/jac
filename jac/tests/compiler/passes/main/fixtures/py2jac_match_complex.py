"""Fixture for a complex literal in a match value pattern (E5044)."""

def classify(x):
    match x:
        case 1 + 2j:
            return "complex"
        case _:
            return "other"
