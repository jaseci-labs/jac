"""Anonymous-region inference for unrooted spawns (#7857 Phase D).

A graph built from fresh node locals, connected only among themselves,
and consumed by an expression-statement spawn is provably unrooted: the
conservative may-reach-root scan proves it, and RegionInferPass wraps the
extent in a real `in Region() { }` open -- arena allocation for the nodes,
graph rows retired at the handle's death, bulk free after the spawn, and
the same drop hooks on the Python backend. Any contact with root or an
escape declines the inference. Output stays byte-identical across gc modes
either way.
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
import jaclang.compiler.frontend.unitree as uni;

glob FIXDIR = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _compile_mod(fixture: str) -> any {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXDIR, fixture),
            options=CompileOptions(aot_mode=True, memory_profile="rc")
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        return ir;
    } finally {
        pop_native_target(prev);
    }
}

test "unrooted spawn desugars to one anonymous open" {
    ir = _compile_mod("anon_region_spawn.jac");
    opens = ir.get_all_sub_nodes(uni.OpenStmt);
    assert len(opens) == 1 , opens;
    assert isinstance(opens[0].target, uni.FuncCall) , opens[0].target;
    assert loop_body_locals(opens[0].body) == ["a", "b", "c"] , loop_body_locals(
        opens[0].body
    );
}

test "root contact declines the inference" {
    ir = _compile_mod("anon_region_rooted.jac");
    assert not ir.get_all_sub_nodes(uni.OpenStmt) , ir.get_all_sub_nodes(uni.OpenStmt);
}

test "escaping member declines the inference" {
    ir = _compile_mod("anon_region_escape.jac");
    assert not ir.get_all_sub_nodes(uni.OpenStmt) , ir.get_all_sub_nodes(uni.OpenStmt);
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
                    "build",
                    "--native",
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
                    "build",
                    "--native",
                    os.path.join(FIXDIR, fixture),
                    "--memory",
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
