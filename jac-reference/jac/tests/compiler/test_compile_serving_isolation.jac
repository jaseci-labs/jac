"""Compile-time serving isolation.

Type-checking a file must not activate the serving stack: no module under
jaclang.scale, jaclang.server, or jaclang.data may be imported (executed) as
a side effect of compiling or checking source. Two historical channels are
pinned here:

1. Kernel context bootstrap: the type system lives as OSP nodes and edges,
   and a type-graph traversal (e.g. reading an enum's members) must answer
   from the transient adjacency without materializing an ExecutionContext,
   whose construction reaches the scale plugin and the server session.
2. Import resolution: boundary-facts classification resolves every import
   statement in a module; the resolver must answer with specs and file
   paths without executing the named module or its parent packages.

Each probe runs a real `jac check` in a child interpreter and scans
sys.modules at exit (os._exit is intercepted so the scan survives the CLI's
hard exit); a single serving module present after the check is a failure,
regardless of any try/except swallowing on the way there.
"""

import os;
import subprocess;
import sys;
import from pathlib { Path }
import from tests.support { JAC_ROOT }

glob FIXTURES = str(Path(__file__).parent / "fixtures"),
     _PROBE_SCRIPT = """
import os
import runpy
import sys

real_exit = os._exit


def scan_and_exit(code=0):
    woken = sorted(
        n for n in sys.modules
        if n.startswith(("jaclang.scale", "jaclang.server", "jaclang.data"))
    )
    if woken:
        print("serving modules woken by check:", ", ".join(woken))
        sys.stdout.flush()
        real_exit(3)
    real_exit(code)


os._exit = scan_and_exit
sys.path.insert(0, os.environ["PROBE_JAC_ROOT"])
sys.argv = ["jac", "check", os.environ["PROBE_FIXTURE"]]
try:
    runpy.run_module("jaclang", run_name="__main__", alter_sys=True)
except SystemExit as exc:
    scan_and_exit(int(exc.code) if isinstance(exc.code, int) else 1)
scan_and_exit(0)
""";


def _check_probe(fixture: str) -> tuple[int, str] {
    env: dict[str, str] = dict(os.environ);
    env["PROBE_JAC_ROOT"] = JAC_ROOT;
    env["PROBE_FIXTURE"] = str((Path(FIXTURES) / fixture).resolve());
    proc = subprocess.run(
        [sys.executable, "-c", _PROBE_SCRIPT],
        cwd=JAC_ROOT,
        env=env,
        capture_output=True,
        text=True,
    );
    return (proc.returncode, proc.stderr + proc.stdout);
}


test "type-graph traversal wakes no serving module" {
    (code, out) = _check_probe("transient_enum_probe.jac");
    assert code == 0 , out;
}

test "import resolution wakes no serving module" {
    (code, out) = _check_probe("serving_import_probe.jac");
    assert code == 0 , out;
}
