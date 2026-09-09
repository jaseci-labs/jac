"""Zero-copy gate of the fat-descriptor migration (#7870): a step-free
string slice is a view with no per-slice allocation -- root-retained
under managed modes, rootless and derivation-bounded (item 2's checker
rules) under the enforced headerless build. Behavior byte-identical
across modes."""

import os;
import re;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "str_slice_views.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _probe_fn_ir(gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    text = str(ir.gen.llvm_ir);
    m = re.search(r'define[^\n]*@"?probe"?\([^\n]*\n(.*?)\n\}', text, re.DOTALL);
    assert m , "probe fn not found in IR";
    return m.group(1);
}

test "managed slices are allocation-free views" {
    body = _probe_fn_ir("rc", False);
    assert "s.view" in body , "no view construction in managed slice";
    assert "__rc_alloc" not in body , "managed slice still allocates";
}

test "enforced headerless slices are rootless allocation-free views" {
    body = _probe_fn_ir("none", True);
    assert "s.view" in body , "no view construction in enforced slice";
    assert "__jac_halloc" not in body , "enforced slice still allocates";
    assert "s.view.root" not in body , "headerless view carries a root store";
    assert "__jac_rc_retain" not in body , "enforced slice emits rc traffic";
}

test "slice-view output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"zc_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
        }
        assert outs["rc"].endswith("end\n") , outs["rc"];
        assert outs["none"] == outs["rc"] , f"{outs['none']} vs {outs['rc']}";
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}
