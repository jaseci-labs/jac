"""Walkers built from class values spawn natively as the Python tier runs them.

The static type of the spawned walker is a base pass; the runtime class is any
subclass, including subclasses declared in other modules and ones that walk
the tree through a marker base. Class names come from `__name__` on the class
value. The Python tier also echoes reported values at spawn; those lines carry
an `@` prefix and are dropped before comparing.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED: list[str] = [
         "Count +r 1 +a 2 +c 3 -c -a +b 4 -b -r",
         "Once once:r",
         "TreePass +r +a +c -c -a +b -b -r",
         "Once once:r",
         "Count +r 1 +a 2 +c 3 -c -a +b 4 -b -r",
         "@r @a @c @b",
         "Count 0",
         "any 4 Count"
     ];

def output_lines(text: str) -> list[str] {
    return [
        line
        for line in text.split("\n")
        if line.strip()
    ];
}

def python_tier_run(fixture: str) -> list[str] {
    proc = subprocess.run(
        jac_command("run", "-b", "python", os.path.join(FIXTURES, fixture)),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"python tier failed: {proc.stderr[-800:]}";
    return [
        line
        for line in output_lines(proc.stdout)
        if " " in line or not line.startswith("@")
    ];
}

def native_run(fixture: str) -> list[str] {
    binary = os.path.join(tempfile.mkdtemp(), "spawn_values.bin");
    build = subprocess.run(
        jac_command("build", "--native", os.path.join(FIXTURES, fixture), "-o", binary),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert build.returncode == 0 , f"native build failed: {build.stderr[-1200:]}";
    assert "native seam" not in build.stderr , build.stderr[-1200:];
    proc = subprocess.run([binary], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]}";
    return output_lines(proc.stdout);
}

test "base-typed walkers from class values spawn their runtime class" {
    native = native_run("spawn_values.jac");
    assert native == EXPECTED , f"native output {native}";
    assert python_tier_run("spawn_values.jac") == native;
}
