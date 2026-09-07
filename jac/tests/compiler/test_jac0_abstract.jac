"""Seed compilation preserves abstract contracts and concrete overrides."""
import from jaclang.jac0 { compile_jac }

test "seed abstract instance and static methods require concrete overrides" {
    source = "class Contract { def value(self: Contract, x: int) -> int abst; "
        + "static def label -> str abst; }\n"
        + "class Concrete(Contract) { "
        + "def value(self: Concrete, x: int) -> int { return x + 1; } "
        + "static def label -> str { return 'ready'; } }\n";
    namespace: dict[str, any] = {};
    exec(
        compile(compile_jac(source, "abstract_seed.jac"), "abstract_seed.jac", "exec"),
        namespace
    );
    contract = namespace["Contract"];
    assert contract.__abstractmethods__ == {"value", "label"};
    with testraises(TypeError) {
        contract();
    }
    concrete = namespace["Concrete"];
    assert concrete().value(7) == 8;
    assert concrete.label() == "ready";
}
