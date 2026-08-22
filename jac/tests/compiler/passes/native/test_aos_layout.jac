"""By-value AoS element buffers (#7870 item 3): under enforced
headerless codegen a `list[own T]` of a scalar-fielded archetype lowers
to a contiguous by-value buffer (List.aos.T) with move-in appends and
in-place element drops through the recursive drop registry; managed
modes keep pointer elements and the annotation erases, so output is
byte-identical across gc modes. The macOS `leaks` gate pins the
teardown exact (the deferred Valgrind-matrix stand-in)."""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "aos_layout.jac"
     ),
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

test "enforced list[own T] lowers to the by-value AoS family" {
    enforced = _compile_ir("none", True);
    assert "List.aos.Cell" in enforced , "no AoS family in enforced build";
    managed = _compile_ir("rc", False);
    assert "List.aos.Cell" not in managed , "managed build must keep pointer elements";
}

test "AoS output is byte-identical across gc modes and leak-free" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        bins: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"aos_{mode}");
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
            outs[mode] = ran.stdout;
            bins[mode] = out_bin;
        }
        lines = outs["none"].split("\n");
        assert lines[0].isdigit() , outs["none"];
        assert sorted(lines[1:13]) == sorted([f"drop {i}" for i in range(12)]) , outs[
            "none"
        ];
        assert outs["rc"] == outs["none"] , f"{outs['rc']} vs {outs['none']}";
        assert outs["cycles"] == outs["none"] , outs["cycles"];
        if shutil.which("leaks") {
            lk = subprocess.run(
                ["leaks", "--atExit", "--", bins["none"]],
                capture_output=True,
                text=True
            );
            assert "0 leaks for 0 total leaked bytes" in lk.stdout , lk.stdout[-2000:];
        }
    }
}
