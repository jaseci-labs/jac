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
