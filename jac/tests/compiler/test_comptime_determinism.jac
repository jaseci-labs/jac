"""Comptime values must not carry the compiler process's set iteration order.

`JcirGenPass._materialize` lowers a comptime `set` to a `set([...])` literal by
iterating it. Python randomizes string hashes per process, so iterating the set
directly baked a per-process element order into the emitted constant: the same
source compiled in two processes produced different bytecode, and therefore
different `.jir` bytes. That breaks build reproducibility and the content
addressing the seeded JIR cache relies on.

Three subprocesses with different `PYTHONHASHSEED` must agree byte for byte.
Before the fix they produced three distinct digests.
"""

import os;
import subprocess;
import sys;
import from pathlib { Path }
import from tests.support { JAC_ROOT }

glob REPO: str = str(Path(JAC_ROOT).parent),
     FIXTURE: str = str(
         Path(JAC_ROOT) / "tests" / "compiler" / "fixtures" / "comptime_set_order.jac"
     ),
     PROBE: str = """
import hashlib, sys
from jaclang.compiler.driver.program import JacProgram
from jaclang.compiler.driver.compile_options import CompileOptions
mod = JacProgram().compile(file_path=sys.argv[1], options=CompileOptions())
bc = getattr(mod.gen, "py_bytecode", None) if mod is not None else None
print("SHA=" + (hashlib.sha256(bc).hexdigest() if bc else "NONE"))
print("ORDER=" + ",".join(tuple({"cron", "interval", "trigger", "date", "walker"})))
""";

def _digest_under_seed(seed: str) -> tuple[str, str] {
    env: dict[str, str] = dict(os.environ);
    env["PYTHONHASHSEED"] = seed;
    proc = subprocess.run(
        [sys.executable, "-c", PROBE, FIXTURE],
        cwd=REPO,
        capture_output=True,
        text=True,
        env=env
    );
    assert proc.returncode == 0 , (
        f"probe failed for seed {seed} (rc={proc.returncode}):\n{proc.stderr[-1500:]}"
    );
    (sha, order) = ("", "");
    for line in proc.stdout.splitlines() {
        if line.startswith("SHA=") {
            sha = line[4:];
        } elif line.startswith("ORDER=") {
            order = line[6:];
        }
    }
    assert sha and sha != "NONE" , f"no bytecode for seed {seed}";
    return (sha, order);
}

test "a comptime set compiles to identical bytecode under any hash seed" {
    digests: set = set();
    orders: set = set();
    sampled = 0;
    for s in [str(i) for i in range(1, 13)] {
        r = _digest_under_seed(s);
        digests.add(r[0]);
        orders.add(r[1]);
        sampled += 1;
        if len(orders) > 1 and sampled >= 3 {
            break;
        }
    }
    assert len(orders) > 1 , (
        "PYTHONHASHSEED did not vary set iteration order across "
        f"{sampled} seeds, so this test cannot detect the defect it guards"
    );
    assert len(digests) == 1 , (
        f"comptime lowering is hash-seed dependent: {len(digests)} distinct "
        f"digests across seeds: {sorted(digests)}"
    );
}
