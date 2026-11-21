import from jaclang.compiler.frontend.parser.frontend { parse }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.tools.reactive_use_walk { ReactiveUseWalker }

test "reactive walker preserves assignment values and scope boundaries" {
    (mod, failed) = parse(
        "def outer { count = count + 1; print(count); state.field = count; "
            + "print(state.count); def inner { count = count + 1; } "
            + "obj Nested { has count: int = 0; } "
            + "f = lambda { count; }; }",
        "reactive_walk.jac"
    );
    assert not failed;
    outer = mod.body[0];
    assert isinstance(outer, uni.Ability);
    walk = ReactiveUseWalker(reactive={"count", "state"});
    for stmt in outer.body {
        stmt spawn walk;
    }
    assert [write[2] for write in walk.writes] == ["count"];
    assert [read[2] for read in walk.reads] == ["count", "count", "count"];
    boundary = ReactiveUseWalker(reactive={"count"});
    outer spawn boundary;
    assert not boundary.reads and not boundary.writes;
}
