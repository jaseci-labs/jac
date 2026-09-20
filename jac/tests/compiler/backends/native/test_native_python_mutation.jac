"""Python mutation preserves aliases and the interpreter's setter errors."""
import ctypes;
import types;
import from unittest.mock { PropertyMock, patch }
import from tests.support { compile_native, get_func }

class Target {}

test "Python attributes items and inplace operations preserve aliases" {
    (engine, _) = compile_native("python_mutation.jac", required=True);
    mutate = get_func(engine, "mutate", ctypes.c_bool);
    invalid_item = get_func(engine, "invalid_assignment", None);
    invalid_attr = get_func(engine, "invalid_attribute", None);
    augmented = get_func(engine, "augmented_order", None);
    assignment = get_func(engine, "assignment_order", None);
    for _ in range(100) {
        assert mutate();
        try {
            invalid_item();
            assert False , "item assignment must propagate IndexError";
        } except IndexError {}
        try {
            invalid_attr();
            assert False , "attribute assignment must propagate AttributeError";
        } except AttributeError {}
    }
    events: list[str] = [];
    target = Target();
    rhs = types.SimpleNamespace(value=3);
    def factory(role: str) -> any {
        events.append(role);
        return target if role == "target" else rhs;
    }
    def attribute(*args: any) -> int {
        events.append("get" if not args else "set:" + str(args[0]));
        return 10;
    }
    with patch.object(
        Target, "value", new=PropertyMock(side_effect=attribute), create=True
    ) {
        with patch.object(types, "SimpleNamespace", new=factory) {
            augmented();
            assert events == ["target", "get", "rhs", "set:13"];
            events.clear();
            assignment();
            assert events == ["rhs", "target", "set:3"];
        }
    }
}
