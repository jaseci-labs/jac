"""Test: classmethod / instance method calls returning `Self` resolve via the
receiver class for chained access (issue #5688).

Before the fix, calling a `@classmethod` whose return type is `Self` left the
call expression typed as the raw `Self` TypeVar — any chained attribute access
(`Cls.make().kick()`) errored with E1031 "Cannot access attribute X for type
Self". stdlib classmethods like `datetime.now(...)` exhibited the same issue.

The fix in `_collect_type_var_bindings` pre-seeds `Self` from the receiver
expression when the call's first param will be auto-stripped (bound method
or classmethod), but NOT when the cls param is a real positional (e.g.
staticmethod `object.__new__(self.__class__)` — that path is exercised by
`checker_self_type_attr_access.jac`).
"""

import from typing { Self }
import from datetime { datetime, timezone }


# ─── Case A: stdlib classmethod returning Self (the issue's reproducer) ────
def case_stdlib -> str {
    return datetime.now(timezone.utc).isoformat();
}


# ─── Case B: user-defined classmethod with explicit `cls: type[Self]` ──────
class Box {
    has count: int = 0;

    @classmethod
    def make(cls: type[Self]) -> Self {
        return cls();
    }

    def kick -> int {
        return self.count + 1;
    }
}


def case_classmethod -> int {
    # Box.make() returns Self -> must resolve to Box for .kick() lookup.
    return Box.make().kick();
}


# ─── Case C: instance method returning Self (fluent / builder pattern) ─────
class Builder {
    has value: int = 0;

    def again -> Self {
        return self;
    }

    def total -> int {
        return self.value;
    }
}


def case_instance_method -> int {
    return Builder().again().total();
}
