"""The stub catalog must not carry the builder process's set iteration order.

`TypeEvaluator._init_prelude_from_sources` adopted the ambient typing names
(`Annotated`, `AsyncIterable`, `AsyncIterator`, `Coroutine`) into the builtins
scope by iterating a `set[str]`. Python randomizes string hashes per process, so
the builtins scope's member order, which the catalog persists and module
interfaces index into, changed from one build to the next. Two processes then
disagreed on the interface digest of any module that leans on builtins: the
equivalence lane's `JAC_IFACE_VERIFY` check failed on `client_runtime_core.jac`
whenever the precompile job and the test job drew different hash seeds.

Subprocesses with different `PYTHONHASHSEED` must build byte-identical
catalogs. Before the fix they produced a different catalog for almost every
seed.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }

glob REPO: str = str(Path(JAC_ROOT).parent),
     PROBE: str = """
import hashlib, sys
from jaclang.compiler.types.stubcat.build import build_catalog
build_catalog(sys.argv[1], only=[], quiet=True)
with open(sys.argv[1], "rb") as f:
    print("SHA=" + hashlib.sha256(f.read()).hexdigest())
print("ORDER=" + ",".join(tuple({"Annotated", "AsyncIterable", "AsyncIterator", "Coroutine"})))
""";

def _catalog_under_seed(seed: str, work: str) -> tuple[str, str] {
    env: dict[str, str] = dict(os.environ);
    env["PYTHONHASHSEED"] = seed;
    out = os.path.join(work, f"stubcat-{seed}.bin");
    proc = subprocess.run(
        [sys.executable, "-c", PROBE, out],
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
    assert sha , f"no catalog for seed {seed}";
    return (sha, order);
}

test "the prelude catalog is byte-identical under any hash seed" {
    work = tempfile.mkdtemp(prefix="stubcat-seed-");
    digests: set = set();
    orders: set = set();
    sampled = 0;
    for s in [str(i) for i in range(1, 13)] {
        r = _catalog_under_seed(s, work);
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
        f"the stub catalog is hash-seed dependent: {len(digests)} distinct "
        f"digests across seeds: {sorted(digests)}"
    );
}
