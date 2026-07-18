"""Lazy singletons whose initializer yields an imprecise (`Any`) value.

The canonical lazy-singleton guards a `T | None` slot with `if slot is None`
and assigns inside the guard. When the initializer's static type is precise the
assignment narrows the slot to `T` and the trailing `return slot` type-checks.
When the initializer is `Any` -- `json.loads`, an untyped third-party call --
the assignment still writes a concrete value, so the slot is no longer `None`;
the narrowing engine must reflect that instead of discarding the narrow and
letting the declared `T | None` cascade into a misleading return diagnostic.
"""

import json;

glob _counts_cache: (dict[str, int] | None) = None;

"""Parse once, cache, and return the parsed mapping (global-slot singleton)."""
def load_counts -> dict[str, int];


obj Response {
    has text: str = "{}",
        _json_cache: (dict[str, int] | None) = None;

    """Parse the body once and memoize it (attribute-slot singleton)."""
    def json -> dict[str, int];
}
