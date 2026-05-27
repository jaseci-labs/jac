"""Unresolvable Union tuple strings still fall back to Literal types."""

import from typing { Union }

glob Unresolved = Union[('NotAType', 'AlsoNotAType')];

def bad_return -> Unresolved {
    return 42;
}
