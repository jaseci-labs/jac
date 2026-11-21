"""End-of-iteration releases of loop-body reference locals are null-guarded.

At the end of every iteration the compiler releases each reference-typed local
declared in the loop body, whether or not that iteration assigned it.
Unguarded, each one was a release call plus a null store, so a loop whose
branches each read through their own local spent most of its time releasing
locals it never assigned. Each release is now behind an inline null test, so an
unassigned local costs a load and a not-taken branch.

The IR test pins the guard. The run tests check that results are unchanged,
that an object is still dropped at the end of the iteration that assigned it
(a guard that skipped the release would only delay the drop to the next
reassignment or the loop exit), and that a 2 GB string churn through branch
locals fits in a 1 GB address space.
"""

import os;
import resource;
import subprocess;
import tempfile;
import ctypes;
import from tests.support {
    compile_native,
    compile_native_ir,
    get_func,
    jac_command,
    TESTS_DIR
}

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "loop_local_release.jac"
     ),
     DROP_ORDER = [
         "use 0",
         "end 0",
         "drop 0",
         "use 1",
         "end 1",
         "drop 1",
         "use 2",
         "end 2",
         "drop 2",
         "use 3",
         "end 3",
         "drop 3",
         "after loop"
     ],
     EXPECTED = "\n".join(["69650", "2000000000"] + DROP_ORDER + ["end", ""]);

test "loop-body local releases are guarded by a null test" {
    text = str(compile_native_ir("loop_local_release.jac").gen.llvm_ir);
    for name in ("p0", "p1", "p2", "p3", "s0", "s3", "a", "b") {
        assert f"iter.set.{name}" in text , f"{name}: latch release not null-guarded";
        assert f"iter.rel.{name}" in text , f"{name}: no guarded release block";
    }
}

test "branch-local references compute the same result" {
    (eng, _) = compile_native("loop_local_release.jac");
    f = get_func(
        eng, "branch_locals_sum", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(400, 50) == 69650;
    assert f(2, 1) == 1;
}

def _limit_address_space {
    one_gb = 1 << 30;
    resource.setrlimit(resource.RLIMIT_AS, (one_gb, one_gb));
}

test "branch locals are dropped each iteration and churn in bounded memory" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "loop_local_release");
        res = subprocess.run(
            jac_command("build", "--native", FIXTURE) + ["-o", out_bin],
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , res.stderr;
        ran = subprocess.run(
            [out_bin], capture_output=True, text=True, preexec_fn=_limit_address_space
        );
        assert ran.returncode == 0 , f"exit {ran.returncode}: {ran.stderr[-400:]}";
        assert ran.stdout == EXPECTED , ran.stdout;
    }
}
