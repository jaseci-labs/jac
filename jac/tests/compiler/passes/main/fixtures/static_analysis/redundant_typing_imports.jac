"""Importing names that are now ambient (or that have a lowercase builtin
counterpart) should warn on the import line so users migrate.

Expected warnings:
  - W1103 for 'Callable' and 'Mapping' from typing
  - W1103 for 'Iterable' from collections.abc (also ambient, real source
    module -- proves the per-module registry isn't string-coincidence)
  - W1104 for 'Any' (use lowercase 'any' BuiltinType keyword)

Must NOT warn:
  - 'cast' -- runtime helper, not in the ambient set
  - 'TYPE_CHECKING' -- runtime constant, not in the ambient set
  - aliased 'Callable as Cb' -- alias is intentional user choice
"""

import from typing { Callable, Mapping, Any, cast, TYPE_CHECKING }
import from typing { Callable as Cb }
import from collections.abc { Iterable }

def take_cb(cb: Callable[[], None]) {
    cb();
}

def keys(m: Mapping[str, int]) -> list[str] {
    return list(m.keys());
}

def alias_cb(cb: Cb) {
    cb();
}

def coerce(x: object) -> Any {
    return cast(Any, x);
}

def sum_iter(items: Iterable[int]) -> int {
    total = 0;
    for x in items {
        total = total + x;
    }
    if TYPE_CHECKING {
        total = total + 0;
    }
    return total;
}
