"""General parallel flow calls (#7870 item 4d): the outlining
machinery generalizes from flow for to arbitrary direct calls, with a
heap future record joining at `wait`. Parallel in enforced zero-RC and
atomic-rc builds; cycles, wasm, rc-debug, and any handle whose uses
are not exactly `wait` keep the sequential erasure."""

import os;
import subprocess;
import tempfile;
import from tests.support { compile_mir, jac_command, TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "flow_future.jac"
     ),
     EXPECTED = "940251\n6.0\nend\n",
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

"""The fixture's MIR under `gc_mode`: whether a flow call runs as a spawned
task is the decision step's choice of representation."""
def _compile_mir(gc_mode: str, enforce: bool) -> str {
    return compile_mir(
        FIXTURE,
        "",
        CompileOptions(
            aot_mode=True,
            force_codespace="native",
            na_gc_mode=gc_mode,
            nogc_enforce_all=enforce
        )
    ).mir();
}

test "flow calls outline into future tasks in parallel-capable builds" {
    for (mode, enforce) in (("none", True), ("rc", False)) {
        text = _compile_mir(mode, enforce);
        assert "@pthread_create" in text , f"{mode}: no spawn";
        assert "@pthread_join" in text , f"{mode}: no join";
    }
    seq = _compile_mir("cycles", False);
    assert "@pthread_create" not in seq , "cycles build must stay sequential";
}

test "future output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"fut_{mode}");
            res = subprocess.run(
                jac_command("build", "--native", FIXTURE)
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            assert ran.stdout == EXPECTED , f"{mode}: {ran.stdout}";
        }
    }
}
