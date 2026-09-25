"""Each module emits its own destructors and trace functions, and a cycle
collection runs in whichever module triggers it. Its lookup table only knew
its own module's destructors, so objects another module allocated were
treated as having no children and every cycle through them survived: a
program collecting from `main` never reclaimed a cycle built in an imported
module. Modules now register their pairs in a shared registry at start-up,
and a lookup miss falls back to it."""

import from tests.support { jac_command }
import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "cycle_collect_xmod_main.jac"
     );

test "cycles built in another module are collected from either module" {
    out = os.path.join(tempfile.mkdtemp(), "cycle_collect_xmod");
    comp = subprocess.run(
        jac_command("build", "--native", FIXTURE, "-o", out),
        capture_output=True,
        text=True,
        timeout=300
    );
    assert comp.returncode == 0 , comp.stderr[-800:];
    proc = subprocess.run([out], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , proc.stderr[-800:];
    lines = proc.stdout.strip().splitlines();
    assert lines == ["collected_here 40", "collected_there 80"] , lines;
}
