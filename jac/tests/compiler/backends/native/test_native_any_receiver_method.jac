"""A method call on an `any` receiver refuses loudly instead of vanishing."""

import os;
import ctypes;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT, compile_native, get_func }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "any_receiver_method_refusal.jac",
     TWIN_SRC = (
         "glob OP: int = 8;\n\n"
         "obj TypedBox {\n"
         "    has items: list[int] = [],\n"
         "        code: bytearray = bytearray();\n"
         "}\n\n"
         "def typed_field_append -> int {\n"
         "    box = TypedBox();\n"
         "    box.items.append(OP);\n"
         "    box.items.append(OP);\n"
         "    box.code.append(OP);\n"
         "    return len(box.items) * 10 + len(box.code);\n"
         "}\n"
     );

glob _MEMO: list[any] = [];

"""Compile the fixture once and return the source lines each E5092 refusal
points at, and the line span of each top-level function."""
def measured -> tuple[any, ...] {
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, FIXTURE);
    prog = JacProgram();
    prog.compile(file_path=path, options=CompileOptions(force_codespace='native'));
    refused = [
        (e.loc.first_line, e.pretty_print())
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5092" and e.loc is not None
    ];
    spans: dict[str, tuple[int, int]] = {};
    lines = open(path).read().splitlines();
    for (i, line) in enumerate(lines, 1) {
        if line.startswith("def ") {
            name = line[4:].split("(")[0].split(" ")[0];
            end = i;
            while end < len(lines) and lines[end - 1] != "}" {
                end += 1;
            }
            spans[name] = (i, end);
        }
    }
    out = (refused, spans, );
    _MEMO.append(out);
    return out;
}

"""The refusals reported inside function `name`."""
def refusals_in(name: str) -> list[str] {
    (refused, spans) = measured();
    (first, last) = spans[name];
    return [
        said
        for (line, said) in refused
        if first <= line <= last
    ];
}


test "mutating and reading methods on an any receiver refuse their callable" {
    # These calls used to lower to nothing at all: the call was dropped from
    # the IR and the function returned as if it had run.
    for fn in ["any_field_append", "any_field_bytearray_append", "any_param_count"] {
        assert refusals_in(fn) , (
            f"{fn} must refuse its `any` receiver method call, got: {measured()[0]}"
        );
    }
}


test "the concretely typed twins still lower and run" {
    assert not refusals_in("typed_field_append") , str(measured()[0]);
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "typed_twin.jac"), "w") as f {
            f.write(TWIN_SRC);
        }
        (eng, _) = compile_native("typed_twin.jac", tmp);
        run = get_func(eng, "typed_field_append", ctypes.c_int64);
        assert run() == 21;
    }
}


test "a File parameter's methods lower without a preceding open" {
    # The File helpers used to be emitted only by `open()`, so `fp.read()` on
    # a parameter in a unit that never opens a file found no method and was
    # dropped the same silent way.
    assert not refusals_in("file_param_read") , str(measured()[0]);
}
