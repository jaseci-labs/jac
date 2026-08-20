"""Importing a name the ambient set already provides is refused (E1125).

The W1103 advisory this fixture used to pin escalated to a hard error
once the per-name identity audit (test_ambient_identity_audit.jac)
certified every ambient name IDENTICAL across spellings: same canonical
declaration, same assignability, same diagnostic stream. The import buys
nothing the ambient binding does not already give -- and when the source
is `typing`, the import alone keeps the module off the native pathway
(native_default_verdict: "unresolved import 'typing'").

Expected refusals:
  - E1125 for 'Callable' and 'Mapping' from typing
  - E1125 for 'Iterable' from collections.abc (also ambient, real source
    module -- proves the per-module registry isn't string-coincidence)

Must NOT fire:
  - 'cast' -- runtime helper, not in the ambient set
  - 'TYPE_CHECKING' -- runtime constant, not in the ambient set
  - aliased 'Callable as Cb' -- alias is intentional user choice, and the
    ambient set cannot provide the chosen local name

W1103 itself survives only for bootstrap-compiled modules
(jaclang/jac0core/), where jac0.py resolves names solely through real
imports and the advisory is therefore not actionable.

'Any' is not exercised here: importing it from typing is a hard error
(E1122), covered by typing_any_refused.jac.
"""

import from typing { Callable, Mapping, cast, TYPE_CHECKING }
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

def coerce(x: object) -> any {
    return cast(int, x);
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
