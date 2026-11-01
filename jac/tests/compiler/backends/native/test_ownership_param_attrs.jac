"""Ownership contract positions lower to LLVM parameter attributes (#7857 Phase A).

`own` and `&mut` params are exclusive (noalias); `&` is exclusive-read
(noalias + readonly); `imm` is deep-frozen (readonly, but may alias other
imm handles so no noalias). Managed params carry no ownership attributes.
The membrane makes these facts stronger than usual: managed code holds no
aliases into the owned world, and nothing unsafe can undermine them.

`readonly` appears only in builds without refcounts: under `rc` and `managed`
a retain or release writes the borrowed object's count header through the
pointer, and LLVM deletes plain stores through a `readonly` argument.
"""

import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import from tests.support { compile_native_ir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = "ownership_param_attrs.jac";

def _compile_ir(gc_mode: (str | None) = None) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        fx = compile_native_ir(
            FIXTURE, options=CompileOptions(aot_mode=True, na_gc_mode=gc_mode)
        );
        assert fx.llvm_ir() , f"no native IR for {FIXTURE}";
        return fx.llvm_ir();
    } finally {
        pop_native_target(prev);
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
    line = _fn_line(_compile_ir("none"), "attr_reader");
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
    line = _fn_line(_compile_ir("none"), "attr_viewer");
    assert "readonly" in line , line;
    assert "noalias" not in line , line;
}

test "refcounted builds keep borrow and imm params writable" {
    for gc_mode in ("cycles", "rc") {
        ir = _compile_ir(gc_mode);
        reader = _fn_line(ir, "attr_reader");
        assert "noalias" in reader , reader;
        assert "readonly" not in reader , reader;
        viewer = _fn_line(ir, "attr_viewer");
        assert "readonly" not in viewer , viewer;
        assert "noalias" not in viewer , viewer;
    }
}

test "managed params carry no ownership attributes" {
    line = _fn_line(_compile_ir(), "attr_plain");
    assert "noalias" not in line , line;
    assert "readonly" not in line , line;
}
