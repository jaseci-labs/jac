"""Concurrent launcher starts never trip over each other's cache write probe.

Every engine process (test262 runs thousands in parallel) checks that the
cache root is writable by creating and removing a probe file there. The probe
had one shared name, so a second process could remove the first's probe
before the first did, and the first's os.remove raised FileNotFoundError
("Uncaught exception: [Errno 2] No such file or directory:
'.../.jac-write-probe'"). NaIRGen lowered os.remove to a bare unlink that
ignored the error; the bundled os.remove raises it like CPython does, so the
race surfaced. Each process now probes with a name of its own.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "parallel cache probes of one directory all succeed" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "cache_probe_race");
        native_build(str(FIXTURES / "cache_probe_race.jac"), out_bin, memory="rc");
        env = dict(os.environ);
        env["JAC_PROBE_DIR"] = os.path.join(tmp, "shared");
        failures: list[str] = [];
        for _ in range(25) {
            procs = [
                subprocess.Popen(
                    [out_bin],
                    env=env,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                ) for _ in range(24)
            ];
            for proc in procs {
                (out, err) = proc.communicate(timeout=60);
                if proc.returncode != 0 or out.strip() != "True" {
                    failures.append(err.strip() or out.strip());
                }
            }
        }
        assert not failures , f"{len(failures)} probes failed: {failures[0]}";
        assert os.listdir(env["JAC_PROBE_DIR"]) == [];
    }
}
