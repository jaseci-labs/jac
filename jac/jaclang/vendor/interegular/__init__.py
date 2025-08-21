"""
A package to compare python-style regexes and test if they have intersections.
Based on the `greenery`-package by @qntm, adapted and specialized for `lark-parser`
"""

from typing import Iterable, Tuple

from interegular.fsm import FSM
from interegular.patterns import Pattern, parse_pattern, REFlags, Unsupported, InvalidSyntax
from interegular.comparator import Comparator
from interegular.utils import logger

__all__ = ['FSM', 'Pattern', 'Comparator', 'parse_pattern', 'compare_patterns', 'compare_regexes', '__version__', 'REFlags', 'Unsupported',
           'InvalidSyntax']


def compare_regexes(*regexes: str) -> Iterable[Tuple[str, str]]:
    """
    Checks the regexes for intersections. Returns all pairs it found
    """
    c = Comparator({r: parse_pattern(r) for r in regexes})
    print(c._patterns)
    return c.check(regexes)


def compare_patterns(*ps: Pattern) -> Iterable[Tuple[Pattern, Pattern]]:
    """
    Checks the Patterns for intersections. Returns all pairs it found
    """
    c = Comparator({p: p for p in ps})
    return c.check(ps)


__version__ = "0.3.3"
