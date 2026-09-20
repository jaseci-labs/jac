"""The jac0 seed transpiler emits the class bases the real compiler emits.

The seed used to append `abc.ABC` to the bases of any class holding an
abstract member. The real compiler only decorates the member with
`@abstractmethod`, so a seed-compiled `obj X(Protocol)` with an `abst` member
picked up a non-protocol base and died at class creation during bootstrap.
"""

import from jaclang.jac0 { compile_jac }


test "seed does not inject an ABC base for abstract members" {
    src = "obj Sink(Protocol) {\n    def emit(x: int) -> None abst;\n}\n";
    out = compile_jac(src, "seed_abstract.jac");
    assert "class Sink(Protocol):" in out , out;
    assert "_jac_abc.ABC" not in out , out;
    assert "@_jac_abc.abstractmethod" in out , out;
}
