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

"""Compile the fixture once under forced native and return the functions it
demoted to Python and the demotion report it wrote to stderr."""
def measured -> tuple[any, ...] {
    import contextlib;
    import io;
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, FIXTURE);
    prog = JacProgram();
    buf = io.StringIO();
    with contextlib.redirect_stderr(buf) {
        ir = prog.compile(
            file_path=path, options=CompileOptions(force_codespace='native')
        );
    }
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    iface: any = ir.gen.native_iface;
    demoted = set(iface.demoted) if iface is not None else set();
    out = (demoted, buf.getvalue(), );
    _MEMO.append(out);
    return out;
}

"""Whether function `name` was demoted to Python."""
def refused(name: str) -> bool {
    return name in measured()[0];
}


test "mutating and reading methods on an any receiver demote their callable" {
    # These calls used to lower to nothing at all: the call was dropped from
    # the IR and the function returned as if it had run.
    for fn in ["any_field_append", "any_field_bytearray_append", "any_param_count"] {
        assert refused(fn) , (
            f"{fn} must refuse its `any` receiver method call and demote: {measured()}"
        );
        assert f"demoting {fn} " in measured()[1] , (
            f"the demotion of {fn} must be reported: {measured()[1]}"
        );
    }
}


test "the concretely typed twins still lower and run" {
    assert not refused("typed_field_append") , str(measured()[0]);
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
    assert not refused("file_param_read") , str(measured()[0]);
}
