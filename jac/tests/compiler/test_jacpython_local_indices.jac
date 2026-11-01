"""Python local-slot ordering through the shipped compiler boundary."""
import ctypes;
import dis;
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

test "uninitialized locals at slots 63 and 64 raise their error" {
    for filler_count in [62, 63] {
        lines = ["def read_local(flag):"];
        for index in range(filler_count) {
            lines.append(f"    filler_{index} = {index}");
        }
        lines.extend(
            ["    if flag:", "        high_local = 1", "    return high_local"]
        );
        namespace: dict[str, any] = {};
        pyexec(pycompile("\n".join(lines) + "\n", "local_slots.py", "exec"), namespace);
        read_local = namespace["read_local"];
        assert read_local(True) == 1;
        raised = False;
        try {
            read_local(False);
        } except UnboundLocalError {
            raised = True;
        }
        assert raised;
    }
}

test "definitely assigned high locals keep unchecked loads" {
    # This code-shape assertion covers JacPython's optimizer only. Stock
    # CPython emits its own LOAD_FAST_CHECK layout for this source.
    if not hasattr(ctypes.pythonapi, "_PyJac_CompilerRequired") {
        return;
    }
    if ctypes.pythonapi._PyJac_CompilerRequired() != 1 {
        return;
    }
    lines = ["def read_local(flag):"];
    for index in range(63) {
        lines.append(f"    filler_{index} = {index}");
    }
    lines.extend(
        [
            "    if flag:",
            "        high_local = 1",
            "    else:",
            "        high_local = 2",
            "    return high_local"
        ]
    );
    namespace: dict[str, any] = {};
    pyexec(pycompile("\n".join(lines) + "\n", "local_slots.py", "exec"), namespace);
    read_local = namespace["read_local"];
    assert read_local(True) == 1;
    assert read_local(False) == 2;
    loads: list[str] = [];
    for instruction in dis.get_instructions(read_local) {
        if instruction.argval == "high_local"
            and instruction.opname.startswith("LOAD_FAST") {
            loads.append(instruction.opname);
        }
    }
    assert len(loads) > 0;
    assert "LOAD_FAST_CHECK" not in loads;
}
