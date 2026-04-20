"""Regression fixture: `super()` inside a method returns the parent instance.

Before the fix, `super()` was being type-checked as a constructor call on the
parent class: `_get_type_of_super` returned `parent_class_type.clone_as_instance()`
for the bare `super` Name, and then `validate_call_args` fell through to the
generic "call" path, which tried to resolve `__call__`/`__init__` on that
instance. With no match it returned Unknown, so `super().to_dict()` became
`Unknown.to_dict()` and cascaded into E1002/E1001 on the caller.

After the fix, `super()` short-circuits in `validate_call_args` — the return
type of the call is the same as the bare `super` expression (the parent
instance), matching Python semantics where attribute access through `super()`
dispatches through the parent's MRO.

This fixture should produce 0 errors.
"""

obj Base {
    has foo: str = "base";

    def to_dict -> dict {
        return {"foo": self.foo};
    }
}

obj Child(Base) {
    has bar: str = "child";

    def to_dict -> dict {
        base = super().to_dict();
        base["bar"] = self.bar;
        return base;
    }
}
