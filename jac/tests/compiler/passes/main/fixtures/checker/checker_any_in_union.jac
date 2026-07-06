"""Fixture for issue #7158: `Any` must absorb inside a union for attribute access.

`typing.Any` used as an annotation resolves to the `Any` class (not the
internal `AnyType`). Attribute-access handling must recognize that form as a
wildcard: access on `T | ... | Any` validates only the non-`Any` members and
yields `result | Any` -- it must NOT report the attribute "missing from Any".

Scope note: assignability is intentionally left strict. Jac rejects bare
explicit `Any -> Concrete` to force narrowing, and `T | Any` is held to the
same rule; likewise the `result | Any` produced here does not flow into a
concrete slot without narrowing. So the fixture exercises attribute access in
value-neutral positions (the bug the issue reports, e.g. `stream.flush()`)
plus a no-`Any` concrete-union assignment. Every function is well-typed and
must produce zero errors.
"""

import from typing { Any }

obj Base {}

obj Alpha(Base) {
    has tag: str = "a";

    def ping -> bool {
        return True;
    }
}

obj Beta(Base) {
    has tag: str = "b";
}

def attr_on_union_with_any(pick: bool, alt: Any) -> None {
    # `Alpha | Any` -- `.tag` exists on Alpha; Any absorbs, no "missing" error.
    item = Alpha() if pick else alt;
    print(item.tag);
}

def method_on_union_with_any(pick: bool, alt: Any) -> None {
    # Mirrors the issue's `stream.flush()`: a call on `Alpha | Any` in a
    # value-neutral position must not report the method missing from Any.
    item = Alpha() if pick else alt;
    if item.ping() {
        print("ok");
    }
}

def attr_on_multi_any(which: int, alt: Any) -> None {
    # `Alpha | Beta | Any` -- `.tag` exists on both concrete members.
    item = Alpha() if which == 0 else (Beta() if which == 1 else alt);
    print(item.tag);
}

def take_base_or_none(x: Base | None) -> None {}

def assign_concrete_union(u: bool, a: Alpha, b: Beta) -> None {
    # `Alpha | Beta` (no `Any`) -- both are subtypes of Base, so the assignment
    # is sound. This is the assignability that stays valid under the strict
    # `Any` policy.
    val = a if u else b;
    take_base_or_none(val);
}
