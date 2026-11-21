"""The cycle collector freed each white object as soon as its children were
traced, so a garbage object reached through a second reference (another
field, a list holding it twice, a second parent) was visited again after it
had been freed: its header was read from freed memory, and once the memory
was reused, the heap was corrupted. Garbage is now queued during the white
phase and reclaimed after it.

Reading freed memory rarely fails on its own, so on macOS the fixture runs
under Guard Malloc, which turns the read into a fault; elsewhere the test
checks the counts and a clean exit."""

import from tests.support { jac_command }
import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "cycle_collect_shared_child.jac"
     ),
     GUARD_MALLOC = "/usr/lib/libgmalloc.dylib";

def run_fixture -> subprocess.CompletedProcess {
    out = os.path.join(tempfile.mkdtemp(), "cycle_collect_shared_child");
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

test "garbage reached through several references is freed once, after tracing" {
    proc = run_fixture();
    assert proc.returncode == 0 , f"exit {proc.returncode}: {proc.stderr[-800:]}";
    lines = proc.stdout.strip().splitlines();
    assert lines == ["two_fields 400", "list_twice 400", "two_parents 600"] , lines;
}
