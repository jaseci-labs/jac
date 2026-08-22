"""Ownership contract positions lower to LLVM parameter attributes (#7857 Phase A).

`own` and `&mut` params are exclusive (noalias); `&` is exclusive-read
(noalias + readonly); `imm` is deep-frozen (readonly, but may alias other
imm handles so no noalias). Managed params carry no ownership attributes.
The membrane makes these facts stronger than usual: managed code holds no
aliases into the owned world, and nothing unsafe can undermine them.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "passes",
         "native",
         "fixtures",
         "ownership_param_attrs.jac"
     );

def _compile_ir -> str {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=FIXTURE, options=CompileOptions(aot_mode=True, type_check=True)
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        assert ir is not None and ir.gen.llvm_ir is not None;
        return str(ir.gen.llvm_ir);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
}

def _fn_line(ir: str, name: str) -> str {
    for line in ir.split("\n") {
        if line.startswith("define") and name in line {
            return line;
        }
    }
    assert False , f"no define line found for {name}";
    return "";
}

test "shared borrow params are noalias readonly" {
    line = _fn_line(_compile_ir(), "attr_reader");
    assert "noalias" in line , line;
    assert "readonly" in line , line;
}

test "mutable borrow params are noalias but writable" {
    line = _fn_line(_compile_ir(), "attr_writer");
    assert "noalias" in line , line;
    assert "readonly" not in line , line;
}

test "own params are noalias" {
    line = _fn_line(_compile_ir(), "attr_taker");
    assert "noalias" in line , line;
}

test "imm params are readonly but may alias" {
    line = _fn_line(_compile_ir(), "attr_viewer");
    assert "readonly" in line , line;
    assert "noalias" not in line , line;
}

test "managed params carry no ownership attributes" {
    line = _fn_line(_compile_ir(), "attr_plain");
    assert "noalias" not in line , line;
    assert "readonly" not in line , line;
}
