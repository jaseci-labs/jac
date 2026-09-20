"""The jac0 seed gives an abstract member ABC, except under Protocol.

The seed appends `abc.ABC` to any class holding an abstract member, which
is what makes a seed-compiled abstract class refuse instantiation (see
test_jac0_abstract.jac). A Protocol subclass may only inherit protocols,
so adding ABC there makes the class unbuildable: a seed module declaring
`obj X(Protocol)` with an `abst` member died at class creation during
bootstrap with "Protocols can only inherit from other protocols". Protocol
already supplies the abstract semantics, so the seed skips ABC there and
keeps it everywhere else.
"""

import from jaclang.jac0 { compile_jac }


test "a Protocol base does not pick up ABC" {
    src = "obj Sink(Protocol) {\n    def emit(x: int) -> None abst;\n}\n";
    out = compile_jac(src, "seed_protocol.jac");
    assert "class Sink(Protocol):" in out , out;
    assert "_jac_abc.ABC" not in out , out;
    assert "@_jac_abc.abstractmethod" in out , out;
}


test "a non-Protocol base still picks up ABC" {
    src = "class Contract { def value(self: Contract, x: int) -> int abst; }\n";
    out = compile_jac(src, "seed_plain.jac");
    assert "class Contract(_jac_abc.ABC):" in out , out;
    assert "@_jac_abc.abstractmethod" in out , out;
}
