"""Differential identity tests for dependency-light interopbench cells."""

import os;
import subprocess;
import sys;
import from pathlib { Path }


glob INTEROPBENCH = str(
         Path(str(__file__)).resolve().parents[4] / "examples" / "interopbench"
     ),
     SMALL_ARGS = ["100", "10"];


"""Run one kernel variant and return its validated canonical digest."""
def _run_variant(kernel: str, variant: str, expected_metrics: set[str]) -> str {
    source = os.path.join(INTEROPBENCH, "kernels", f"{kernel}.jac");
    assert os.path.exists(source) , f"kernel missing: {source}";
    command = [sys.executable, "-m", "jaclang", "run", source, variant, ] + SMALL_ARGS;
    proc = subprocess.run(command, capture_output=True, text=True, timeout=120,);
    assert proc.returncode == 0 , (
        f"{kernel}/{variant} exited {proc.returncode}\n"
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
        f"{kernel}/{variant}: expected one ns= line, found {timing_count}"
    );
    assert set(metrics.keys()) == expected_metrics , (
        f"{kernel}/{variant}: unexpected metrics {sorted(metrics.keys())}"
    );
    assert len(digest_lines) == 1 , (
        f"{kernel}/{variant}: expected one digest line, found {digest_lines}"
    );
    assert digest_lines[0] , f"{kernel}/{variant}: empty digest";
    return digest_lines[0];
}


test "interopbench differential identity: sv to native scalar call" {
    free = _run_variant("iop_call", "free", {"per_call_ns"});
    bridge = _run_variant("iop_call", "bridge", {"per_call_ns"});
    assert free == bridge , (
        f"iop_call output diverged:\n--- free ---\n{free}\n" f"--- bridge ---\n{bridge}"
    );
}


test "interopbench differential identity: native inverse callback" {
    for _repeat in range(3) {
        free = _run_variant("iop_cb", "free", {"invoke_ns"});
        bridge = _run_variant("iop_cb", "bridge", {"invoke_ns"});
        assert free == bridge , (
            f"iop_cb output diverged:\n--- free ---\n{free}\n"
            f"--- bridge ---\n{bridge}"
        );
    }
}
