"""Parallel flow for in zero-RC enforced builds (#7857 Phase D).

An binary provably contains no refcount operations and no
OSP kernel, and the checker bans every unsound capture from a flow for
body -- so threads are unconditionally safe there. The enforced build
outlines the body, fans element ranges out over pthreads, and joins at
the closing brace; managed modes keep the sequential lowering. Post-join
state is deterministic (disjoint element writes), so output is
byte-identical across thread counts and across gc modes.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "flow_for_parallel.jac"
     ),
     EXPECTED = "81313683\nend\n",
     RED_FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "flow_for_reduce.jac"
     ),
     SHARED_FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "flow_for_rc_shared.jac"
     ),
     RED_EXPECTED = "31712031\n14722\n975010\nend\n",
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _compile_ir_path(path: str, gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=path,
        options=CompileOptions(
            aot_mode=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(ir.gen.llvm_ir);
}

def _compile_ir(gc_mode: str, enforce: bool) -> str {
    return _compile_ir_path(FIXTURE, gc_mode, enforce);
}

def _run_matrix(fixture: str, expected: str) {
    with tempfile.TemporaryDirectory() as tmp {
        bins: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ffr_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", fixture]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            assert ran.stdout == expected , f"{mode}: {ran.stdout}";
            bins[mode] = out_bin;
        }
        for nthreads in ("1", "3", "16") {
            env = dict(os.environ);
            env["JAC_FLOW_THREADS"] = nthreads;
            ran = subprocess.run(
                [bins["none"]], capture_output=True, text=True, env=env
            );
            assert ran.returncode == 0 , f"threads={nthreads}: {ran.stderr}";
            assert ran.stdout == expected , f"threads={nthreads}: {ran.stdout}";
        }
    }
}

test "enforced build fans out over pthreads, managed builds stay sequential" {
    enforced = _compile_ir("none", True);
    assert "pthread_create" in enforced , "no parallel fan-out in enforced build";
    assert "pthread_join" in enforced , "no join in enforced build";
    managed = _compile_ir("cycles", False);
    assert "pthread_create" not in managed , "cycles build must stay sequential";
}

test "rc builds fan out over pthreads with atomic RC" {
    managed_rc = _compile_ir("rc", False);
    assert "pthread_create" in managed_rc , "rc build must fan out (atomic RC)";
    managed_cycles = _compile_ir("cycles", False);
    assert "pthread_create" not in managed_cycles , "cycles build must stay sequential (collector is unsynchronized)";
}

test "rc parallel output is byte-identical across thread counts" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "ffp_rc_par");
        res = subprocess.run(
            [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
                + MODE_FLAGS["rc"]
                + ["-o", out_bin],
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , res.stderr;
        for nthreads in ("1", "3", "16") {
            env = dict(os.environ);
            env["JAC_FLOW_THREADS"] = nthreads;
            ran = subprocess.run([out_bin], capture_output=True, text=True, env=env);
            assert ran.returncode == 0 , f"threads={nthreads}: {ran.stderr}";
            assert ran.stdout == EXPECTED , f"threads={nthreads}: {ran.stdout}";
        }
    }
}

test "shared-capture rc stress is identical across widths and modes" {
    with tempfile.TemporaryDirectory() as tmp {
        bins: dict[str, str] = {};
        outs: dict[str, str] = {};
        for mode in ("rc", "cycles") {
            out_bin = os.path.join(tmp, f"ffs_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", SHARED_FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            bins[mode] = out_bin;
            outs[mode] = ran.stdout;
        }
        assert outs["rc"] == outs["cycles"] , f"{outs['rc']} vs {outs['cycles']}";
        assert outs["rc"].endswith("end\n") , outs["rc"];
        for nthreads in ("1", "8", "16") {
            env = dict(os.environ);
            env["JAC_FLOW_THREADS"] = nthreads;
            ran = subprocess.run([bins["rc"]], capture_output=True, text=True, env=env);
            assert ran.returncode == 0 , f"threads={nthreads}: {ran.stderr}";
            assert ran.stdout == outs["cycles"] , f"threads={nthreads}: {ran.stdout}";
        }
    }
}

test "reduction accumulators keep the parallel fan-out" {
    enforced = _compile_ir_path(RED_FIXTURE, "none", True);
    assert "pthread_create" in enforced , "reductions must not force sequential";
    assert "__jac_ffor_body" in enforced , "no outlined body for reduction loop";
    managed = _compile_ir_path(RED_FIXTURE, "cycles", False);
    assert "pthread_create" not in managed , "cycles build must stay sequential";
}

test "reduction output is byte-identical across gc modes and thread counts" {
    _run_matrix(RED_FIXTURE, RED_EXPECTED);
}

test "output is byte-identical across gc modes and thread counts" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        bins: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ffp_{mode}");
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
            bins[mode] = out_bin;
        }
        assert outs["none"] == EXPECTED , outs["none"];
        assert outs["rc"] == EXPECTED , outs["rc"];
        assert outs["cycles"] == EXPECTED , outs["cycles"];
        for nthreads in ("1", "3", "16") {
            env = dict(os.environ);
            env["JAC_FLOW_THREADS"] = nthreads;
            ran = subprocess.run(
                [bins["none"]], capture_output=True, text=True, env=env
            );
            assert ran.returncode == 0 , f"threads={nthreads}: {ran.stderr}";
            assert ran.stdout == EXPECTED , f"threads={nthreads}: {ran.stdout}";
        }
    }
}
