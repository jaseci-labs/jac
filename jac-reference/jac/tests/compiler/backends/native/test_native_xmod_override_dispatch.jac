"""Overrides declared in an importing module run through base-typed calls.

Layout is decided per module. A base whose own module never subclasses it
used to lay out flat, with no vtable, so a call through a reference typed as
the base bound straight to the base's body -- in the base's own functions,
in its methods calling `self.weight()`, and in the importer that declares
the overrides. Nothing diagnosed it: the call lowered, linked and returned
the base's answer. A rotating-tree base split out of a profiler port into
its own module, with its entry subclasses in another, printed the base's
weights for every entry.

Every class another module can subclass, whose own methods it could
override, now carries a vtable (`open_dispatch` in the layout pass), so the
call dispatches wherever the override was declared. The fixture pins the
values against the Python backend under every memory profile, which is the
point: a call that lands on the wrong body still exits 0.
"""

import from tests.support { assert_native_identity }

import from pathlib { Path }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "an importer's overrides run through references typed as the base" {
    out = assert_native_identity(str(FIXTURES / "xmod_override_main.jac"));
    assert "node 502 502 502 entry 5 calls=2 5020" in out , out;
    assert "node 11 11 11 node 7 110" in out , out;
    assert "total 5746" in out , out;
}
