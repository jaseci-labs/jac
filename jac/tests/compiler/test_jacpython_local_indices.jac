"""Python local-slot ordering through the shipped compiler boundary."""
import from builtins { compile as pycompile, exec as pyexec }

test "large Python local tables preserve closure and argument slots" {
    lines = ["def factory(argument):"];
    for index in range(500) {
        lines.append(f"    local_{index} = argument + {index}");
    }
    lines.extend(
        [
            "    def closure():",
            "        return local_499, local_0, argument",
            "    return closure, lambda value: local_250 + value",
            "def reordered(second, first):",
            "    return first, second"
        ]
    );
    namespace: dict[str, any] = {};
    pyexec(pycompile("\n".join(lines) + "\n", "local_slots.py", "exec"), namespace);
    (closure, shifted) = namespace["factory"](7);
    assert closure() == (506, 7, 7);
    assert shifted(3) == 260;
    assert namespace["reordered"](2, 1) == (1, 2);
}

test "high local slots preserve unbound-local checks" {
    for local_count in [63, 64] {
        lines = ["def read_last():"];
        for index in range(local_count - 1) {
            lines.append(f"    local_{index} = {index}");
        }
        lines.extend(
            [
                "    if False:",
                f"        local_{local_count - 1} = {local_count - 1}",
                f"    return local_{local_count - 1}"
            ]
        );
        namespace: dict[str, any] = {};
        pyexec(
            pycompile("\n".join(lines) + "\n", "unbound_local.py", "exec"), namespace
        );
        caught = False;
        try {
            namespace["read_last"]();
        } except UnboundLocalError {
            caught = True;
        }
        assert caught , f"expected UnboundLocalError for {local_count} local slots";
    }
}
