"""Inline flattening of own-typed fields under headerless codegen (#7857 Phase B).

An `own`-typed field of a concrete archetype is stored by value inside the
parent's allocation in enforced headerless modules: the parent's LLVM struct
embeds the field struct (no pointer slot), field construction lands in
place (no separate malloc), and the parent's drop tears the field down
without a separate free. Managed modes keep pointer fields; program output
stays byte-identical across all three gc modes.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXDIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "main", "fixtures", "nogc_ownfield"
     ),
     FIXTURE = os.path.join(FIXDIR, "own_field_drop_count.jac"),
     MODE_FLAGS = {
         "none": ["--enforce-nogc", "--gc", "none", "--assert-no-rc"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

def _compile_ir_headerless -> str {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=FIXTURE,
            options=CompileOptions(
                aot_mode=True, type_check=True, na_gc_mode="none", nogc_enforce_all=True
            )
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

test "headerless: own field embeds by value in the parent struct" {
    ir = _compile_ir_headerless();
    for line in ir.split("\n") {
        if line.startswith('%"Holder" = type') {
            assert '%"Res"*' not in line , line;
            assert '%"Res"' in line , line;
            return;
        }
    }
    assert False , "no Holder type line found";
}

test "flattened output stays byte-identical across all gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ofi_{mode}");
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
        }
        assert outs["none"] == "drop 0\nmid\n2\ndrop 2\nend\n" , outs["none"];
        assert outs["rc"] == outs["none"] , outs["rc"];
        assert outs["cycles"] == outs["none"] , outs["cycles"];
    }
}
