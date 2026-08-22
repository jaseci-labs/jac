"""Step-2 gate of the fat-descriptor string migration (#7870): the JacStr
descriptor exists and every str crossing of the clib ABI membrane goes
through the wrap/unwrap shims (header-aware wrap outbound, raw-strlen
wrap inbound) while core ops still traffic in i8*. Behavior stays
byte-identical across gc modes."""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "clib_str_membrane.jac"
     ),
     EXPECTED = "0\nTrue\nllo\nend\n",
     MODE_FLAGS = {
         "none": ["--enforce-nogc", "--gc", "none", "--assert-no-rc"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

def _compile_ir(gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, type_check=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(ir.gen.llvm_ir);
}

test "str clib crossings route through the descriptor shims" {
    for (mode, enforce) in (("rc", False), ("none", True)) {
        text = _compile_ir(mode, enforce);
        assert "__jac_str_wrap" in text , f"{mode}: no outbound wrap shim";
        assert "__jac_str_unwrap" in text , f"{mode}: no unwrap shim";
        assert "__jac_str_wrap_raw" in text , f"{mode}: no inbound raw wrap shim";
        assert text.count("call") and "JacStr" in text , f"{mode}: no descriptor type";
    }
}

test "membrane output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"csm_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "nacompile", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            assert ran.stdout == EXPECTED , f"{mode}: {ran.stdout}";
        }
    }
}
