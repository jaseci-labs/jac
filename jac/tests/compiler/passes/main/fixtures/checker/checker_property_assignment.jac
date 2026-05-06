"""Test property and cached_property assignment type checking.

@cached_property is a non-data descriptor (no __set__), so in Python
`obj.attr = value` bypasses the descriptor and stores directly into
instance.__dict__. Assignment should therefore type-check against the
getter's return type.

@property without a setter is a read-only data descriptor and should
emit a dedicated "read-only property" diagnostic on assignment.

NOTE: @property with a @name.setter is handled by get_property_write_type
in the evaluator, but not tested here because the Jac compiler currently
has upstream issues with @name.setter decorators in `obj` definitions
(E0076 duplicate method, E1031 .setter attribute resolution). Once those
are resolved, setter assignment tests should be added.
"""

import from functools { cached_property }

obj Base {
    has name: str = "base";

    @property
    def readonly_val -> int {
        return 100;
    }

    @cached_property
    def cached_val -> str {
        return "cached";
    }

    @cached_property
    def cached_num -> int {
        return 42;
    }
}

obj Holder {
    has base: Base;
}

with entry {
    b = Base();

    # OK: assigning matching type to a @cached_property
    b.cached_val = "new_value";                # <-- OK
    b.cached_num = 7;                          # <-- OK

    # Error: assigning wrong type to a @cached_property (should hit E1001
    # with the GETTER'S return type on the LHS, not the function type)
    b.cached_val = 99;                         # <-- Error (int to str)
    b.cached_num = "not_an_int";               # <-- Error (str to int)

    # Error: assigning to a read-only @property (no setter) — should emit
    # the dedicated read-only diagnostic (E1005), not E1001 vs func type
    b.readonly_val = 1;                        # <-- Error (read-only)

    # Chained access: assignment through another attribute should also work
    h = Holder(base=b);
    h.base.cached_val = "chained";             # <-- OK
    h.base.cached_num = "wrong";               # <-- Error (str to int)
    h.base.readonly_val = 2;                   # <-- Error (read-only)
}
