"""Differential-identity tests over the interopbench native-bridge kernels
(jac/examples/interopbench): one source per cell, oracle variants must produce
byte-identical canonical digests (minus the ns= timing line and m: metrics).

This is the executable witness of marshalled-boundary correctness for the
mixed-JIT scalar cells, the symmetric sv↔na caller/callee pair, and the
full-native view driver. It is the compiler regression net for interop
codegen and wrapper seams surfaced by the suite.

Cross-runtime cells (xop_*) stay out of this gate: they need live servers,
Node, and wasm artifacts. See ci_xruntime.sh instead.
"""

import os;
import subprocess;
import sys;
import from pathlib { Path }


glob INTEROPBENCH = str(
         Path(str(__file__)).resolve().parents[4] / "examples" / "interopbench"
     ),
     SMALL_CHURN = ["200", "20"];


"""Run one jac run invocation and return its validated canonical digest."""
def _run_command(command: list[str], label: str, expected_metrics: set[str]) -> str {
    proc = subprocess.run(command, capture_output=True, text=True, timeout=120,);
    assert proc.returncode == 0 , (
        f"{label} exited {proc.returncode}\n"
        f"stdout: {proc.stdout[-600:] if proc.stdout else '(empty)'}\n"
        f"stderr: {proc.stderr[-600:] if proc.stderr else '(empty)'}"
    );
    timing_count = 0;
    metrics: dict[str, int] = {};
    digest_lines: list[str] = [];
    for line in proc.stdout.splitlines() {
        if not line.strip() {
            continue;
        }
        if line.startswith("ns=") {
            timing_count += 1;
            assert int(line[3:]) >= 0 , f"negative timing: {line}";
        } elif line.startswith("m:") {
            (key, separator, value) = line[2:].partition("=");
            assert separator and key and value , f"malformed metric: {line}";
            assert key not in metrics , f"duplicate metric: {key}";
            metrics[key] = int(value);
        } else {
            digest_lines.append(line);
        }
    }
    assert timing_count == 1 , (
        f"{label}: expected one ns= line, found {timing_count}"
    );
    assert set(metrics.keys()) == expected_metrics , (
        f"{label}: unexpected metrics {sorted(metrics.keys())}"
    );
    assert len(digest_lines) == 1 , (
        f"{label}: expected one digest line, found {digest_lines}"
    );
    assert digest_lines[0] , f"{label}: empty digest";
    return digest_lines[0];
}


"""Run one mixed-JIT kernel variant."""
def _run_kernel(kernel: str, variant: str, expected_metrics: set[str]) -> str {
    source = os.path.join(INTEROPBENCH, "kernels", f"{kernel}.jac");
    assert os.path.exists(source) , f"kernel missing: {source}";
    command = [sys.executable, "-m", "jaclang", "run", source, variant, ] + SMALL_CHURN;
    return _run_command(command, f"{kernel}/{variant}", expected_metrics);
}


"""Run one view-driver variant."""
def _run_view(variant: str, count: str) -> str {
    source = os.path.join(INTEROPBENCH, "harness", "view_driver.jac");
    command = [sys.executable, "-m", "jaclang", "run", source, variant, count, ];
    return _run_command(
        command, f"iop_view/{variant}/{count}", {"view_ns", "materialise_ns"},
    );
}


test "interopbench differential identity: sv to native scalar call" {
    free = _run_kernel("iop_call", "free", {"per_call_ns"});
    bridge = _run_kernel("iop_call", "bridge", {"per_call_ns"});
    assert free == bridge , (
        f"iop_call output diverged:\n--- free ---\n{free}\n--- bridge ---\n{bridge}"
    );
}


test "interopbench differential identity: native inverse callback" {
    for _repeat in range(3) {
        free = _run_kernel("iop_cb", "free", {"invoke_ns"});
        bridge = _run_kernel("iop_cb", "bridge", {"invoke_ns"});
        assert free == bridge , (
            f"iop_cb output diverged:\n--- free ---\n{free}\n"
            f"--- bridge ---\n{bridge}"
        );
    }
}


test "interopbench differential identity: symmetric sv and na callers" {
    digests: set[str] = set();
    for variant in ("sv_local", "sv_to_na", "na_local", "na_to_sv") {
        digests.add(_run_kernel("iop_symmetric", variant, {"per_call_ns"}));
    }
    assert len(digests) == 1 , (
        f"iop_symmetric output diverged across variants: {sorted(digests)}"
    );
}


test "interopbench differential identity: native list and struct views" {
    materialised = _run_view("materialised", "17");
    view = _run_view("view", "17");
    assert materialised == view , (
        f"iop_view output diverged:\n--- materialised ---\n{materialised}\n"
        f"--- view ---\n{view}"
    );
}
