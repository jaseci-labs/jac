"""Fixture for #6982: py2jac must emit valid Jac for match statements.

Tests both mapping patterns (colon separator) and class keyword patterns
(equals separator) to ensure the operator token is correctly injected.
"""
# flake8: noqa


def match_mapping_pattern(value: object) -> None:
    """Match against a dict with a mapping pattern."""
    match value:
        case {"key": 1, "other": 2}:
            return
        case {"nested": x, "val": y}:
            return
        case _:
            return


def match_class_keyword_pattern(value: object) -> None:
    """Match against a class with keyword patterns."""
    match value:
        case Point(x=0, y=0):
            return
        case Point(x=x, y=y):
            return
        case _:
            return


def match_mixed_patterns(value: object) -> None:
    """Match with both positional and keyword patterns."""
    match value:
        case Point(0, 0, label="origin"):
            return
        case Point(x, y, label=name):
            return
        case _:
            return
