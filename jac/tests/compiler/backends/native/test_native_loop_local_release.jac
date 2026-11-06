"""Releases of loop-body reference locals.

A reference local declared in a loop body is released when it is reassigned
and when the function returns, as CPython releases it. The tests check that
results are unchanged, that objects drop in the order the Python backend
prints, and that a 2 GB string churn through branch locals fits in a 1 GB
address space.
"""

import os;
import resource;
import subprocess;
import tempfile;
import ctypes;
import from tests.support {
    assert_native_identity,
    compile_native,
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
     );

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

test "branch locals drop as Python drops them and churn in bounded memory" {
    expected = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
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
        assert ran.stdout == expected , ran.stdout;
    }
}
