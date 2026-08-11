"""Anonymous-region inference for unrooted spawns (#7857 Phase D).

A graph built from fresh node locals, connected only among themselves,
and consumed by an expression-statement spawn is provably unrooted: the
conservative may-reach-root scan stamps it, and codegen wraps the extent
in an implicit anonymous region -- arena allocation for the nodes, graph
rows retired via the region keyring, bulk free after the spawn. Any
contact with root or an escape declines the inference. Output stays
byte-identical across gc modes either way.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXDIR = os.path.join(TESTS_DIR, "compiler", "passes", "native", "fixtures"),
     MODE_FLAGS = {
         "none": ["--gc", "none"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

def _compile_mod(fixture: str) -> any {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXDIR, fixture),
            options=CompileOptions(aot_mode=True, type_check=True, na_gc_mode="rc")
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        return ir;
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
}

test "unrooted spawn stamps one anonymous-region group" {
    ir = _compile_mod("anon_region_spawn.jac");
    assert len(ir.gen.anon_region_open) == 1 , ir.gen.anon_region_open;
    assert len(ir.gen.anon_region_close) == 1 , ir.gen.anon_region_close;
    assert list(ir.gen.anon_region_locals.values()) == [["a", "b", "c"]] , ir.gen.anon_region_locals;
}

test "root contact declines the inference" {
    ir = _compile_mod("anon_region_rooted.jac");
    assert not ir.gen.anon_region_open , ir.gen.anon_region_open;
}

test "escaping member declines the inference" {
    ir = _compile_mod("anon_region_escape.jac");
    assert not ir.gen.anon_region_open , ir.gen.anon_region_open;
}

test "inferred region drops LIFO at close in every gc mode" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ar_{mode}");
            res = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "jaclang",
                    "nacompile",
                    os.path.join(FIXDIR, "anon_region_spawn.jac")
                ]
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
        assert outs["rc"] == "1\n2\n3\ndrop 3\ndrop 2\ndrop 1\ndone\n" , outs["rc"];
        assert outs["none"] == outs["rc"] , outs["none"];
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}

test "declined fixtures still run correctly" {
    with tempfile.TemporaryDirectory() as tmp {
        for fixture in ("anon_region_rooted.jac", "anon_region_escape.jac") {
            out_bin = os.path.join(tmp, "ar_declined");
            res = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "jaclang",
                    "nacompile",
                    os.path.join(FIXDIR, fixture),
                    "--gc",
                    "rc",
                    "-o",
                    out_bin
                ],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{fixture}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{fixture}: {ran.stderr}";
            assert ran.stdout == "1\n2\ndone\n" , f"{fixture}: {ran.stdout}";
        }
    }
}
