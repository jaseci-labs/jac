"""Differential-identity tests over the interopbench native-bridge kernels
(jac/examples/interopbench): one source per cell, oracle variants must produce
byte-identical canonical digests (minus the ns= timing line and m: metrics).

This is the executable witness of marshalled-boundary correctness for the
mixed-JIT scalar cells, the symmetric sv↔na caller/callee pair, and the
full-native view driver. It is the compiler regression net for interop
codegen and wrapper seams surfaced by the suite.

The view cell needs the compiler-only native-accel modules, which the shipped
binary omits; it self-skips there and is gated by ci_bridges.sh under dev
source (see `_native_views_available`).

Cross-runtime cells (xop_*) stay out of this gate: they need live servers,
Node, and wasm artifacts. See ci_xruntime.sh instead.
"""

import importlib.util;
import os;
import subprocess;
import sys;
import from pathlib { Path }


glob INTEROPBENCH = str(
         Path(str(__file__)).resolve().parents[4] / "examples" / "interopbench"
     ),
     SMALL_CHURN = ["200", "20"];


"""Whether the full-native view driver can run here.

view_driver imports `jaclang.jac0core.native_accel` / `native_marshal` to
force-accelerate an external `.na.jac` producer and to type its zero-copy
views. Those compiler-only modules are on `runtime_vendor._DENY_PREFIXES`, so
the shipped binary that runs this compiler suite deliberately omits them. When
absent the view cell is gated by ci_bridges.sh under dev source instead (same
rationale the docstring gives for the cross-runtime cells)."""
def _native_views_available -> bool {
    return importlib.util.find_spec("jaclang.jac0core.native_accel") is not None
    and importlib.util.find_spec("jaclang.jac0core.native_marshal") is not None;
}


"""Run one jac run invocation and return its validated canonical digest.

`zero_metrics` names metrics that MUST be exactly zero for this variant (the
non-selected view path), guarding against a shared bug that reports both
scopes nonzero. Every parsed metric is asserted non-negative."""
def _run_command(
    command: list[str],
    label: str,
    expected_metrics: set[str],
    zero_metrics: set[str] | None = None,
) -> str {
    proc = subprocess.run(
        command, capture_output=True, text=True, timeout=120, env=dict(os.environ),
    );
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
            parsed = int(value);
            assert parsed >= 0 , f"{label}: negative metric {line}";
            metrics[key] = parsed;
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
    for zero_key in (zero_metrics or set()) {
        assert metrics[zero_key] == 0 , (
            f"{label}: non-selected metric {zero_key}={metrics[zero_key]} must be zero"
        );
    }
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


"""Run one view-driver variant.

The non-selected timing scope must be exactly zero: the `view` variant never
materialises (materialise_ns==0) and the `materialised` variant never times the
zero-copy scan (view_ns==0). A shared bug reporting both would pass a pure
metric-key check, so assert the zero explicitly."""
def _run_view(variant: str, count: str) -> str {
    source = os.path.join(INTEROPBENCH, "harness", "view_driver.jac");
    command = [sys.executable, "-m", "jaclang", "run", source, variant, count, ];
    non_selected = {"materialise_ns"} if variant == "view" else {"view_ns"};
    return _run_command(
        command,
        f"iop_view/{variant}/{count}",
        {"view_ns", "materialise_ns"},
        zero_metrics=non_selected,
    );
}


test "interopbench differential identity: sv to native scalar call" {
    free = _run_kernel("iop_call", "free", {"per_call_ns"});
    bridge = _run_kernel("iop_call", "bridge", {"per_call_ns"});
    assert free == bridge , (
        f"iop_call output diverged:\n--- free ---\n{free}\n--- bridge ---\n{bridge}"
    );
    assert free == "call:263997602" , (
        f"iop_call checksum changed from independently computed value: {free}"
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
    if not _native_views_available() {
        return;  # shipped binary omits native_accel/native_marshal (see helper)
    }
    materialised = _run_view("materialised", "17");
    view = _run_view("view", "17");
    assert materialised == view , (
        f"iop_view output diverged:\n--- materialised ---\n{materialised}\n"
        f"--- view ---\n{view}"
    );
    assert view == "view:1275708384" , (
        f"iop_view checksum changed from independently computed value: {view}"
    );
}
