"""A cycle collection could start in the middle of a destructor: releasing
the last reference to a container runs its destructor, which releases the
elements, and every element decrement that leaves a shared object alive
pushes a possible root; once the root buffer reached its threshold, the
collection ran right there. The object being destroyed was still reachable
-- a field assignment released the old value before storing the new one,
and `list.clear()`/`dict.clear()` release each slot before emptying it -- so
the collection traced a container whose elements it had already freed,
reading and writing their headers.

Field assignment now stores the new value before releasing the old one, and
a collection triggered while any destructor is running waits until the
outermost release returns.

Reading freed memory rarely fails on its own, so on macOS the fixture runs
under Guard Malloc, which turns the read into a fault; elsewhere the test
checks the output and a clean exit."""

import from tests.support { jac_command }
import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "collect_during_release.jac"
     ),
     GUARD_MALLOC = "/usr/lib/libgmalloc.dylib";

def run_fixture -> subprocess.CompletedProcess {
    out = os.path.join(tempfile.mkdtemp(), "collect_during_release");
    comp = subprocess.run(
        jac_command("build", "--native", FIXTURE, "-o", out),
        capture_output=True,
        text=True,
        timeout=300
    );
    assert comp.returncode == 0 , comp.stderr[-800:];
    env = os.environ.copy();
    if sys.platform == "darwin" and os.path.exists(GUARD_MALLOC) {
        env["DYLD_INSERT_LIBRARIES"] = GUARD_MALLOC;
    } else {
        env["MALLOC_CHECK_"] = "3";
        env["MALLOC_PERTURB_"] = "165";
    }
    return subprocess.run([out], capture_output=True, text=True, timeout=300, env=env);
}

test "no collection traces a container its destructor is tearing down" {
    proc = run_fixture();
    assert proc.returncode == 0 , f"exit {proc.returncode}: {proc.stderr[-800:]}";
    lines = proc.stdout.strip().splitlines();
    assert lines
        == ["replace_field 0 3000", "clear_list 0 3000", "clear_dict 0 3000"] , lines;
}
