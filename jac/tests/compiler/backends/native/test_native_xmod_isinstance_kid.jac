"""Subclassing an imported flat base keeps inherited fields readable.

A base whose own module neither subclasses it nor names it in an
`isinstance` lays out flat, with its first field at slot 0. An importer's
subclass that is itself an `isinstance` target kept a vtable slot for that
test, so every inherited field sat one slot later than the base put it, the
layouts refused to agree, and each inherited read (`self.key` in the
subclass's own methods, `e.key` after narrowing) demoted with E5092
"inherited field access". Building a rotating-tree base in one module and
its profiler-entry subclasses in another hit exactly this.

A build whose allocations carry a header stamps the class name there, and
`isinstance` answers from it for flat classes, so an `isinstance`-only slot
is dropped and the two units agree. A headerless nogc build has no such
identity and keeps the slot, so it stays loud rather than guessing.
"""

import from tests.support { assert_native_identity }

import from pathlib { Path }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "an isinstance-tested subclass reads fields of an imported flat base" {
    out = assert_native_identity(
        str(FIXTURES / "xmod_isinstance_kid_main.jac"), profiles=["rc", "managed"]
    );
    assert "classify 1505 2011 9" in out , out;
    assert "kind False True 7 1" in out , out;
}
