"""Temporary probe: build and run each callable_probe fixture natively.
Fails on purpose so CI prints the report; never meant to merge."""

import from tests.support { jac_command }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob PROBE_DIR = str(Path(__file__).resolve().parent / "fixtures" / "callable_probe");

def _keep(line: str) -> bool {
    low = line.lower();
    return any(
        key in low
        for key in ["demot", "error", "e5092", "e9003", "help", "ice", "refus", "warn"]
    );
}

def probe_report -> str {
    lines: list[str] = [];
    with tempfile.TemporaryDirectory() as tmp {
        for name in sorted(os.listdir(PROBE_DIR)) {
            if not name.endswith(".jac") {
                continue;
            }
            src = os.path.join(PROBE_DIR, name);
            out_bin = os.path.join(tmp, name[:-4]);
            lines.append(f"===== {name}");
            try {
                comp = subprocess.run(
                    jac_command("build", "--native", src, "-o", out_bin),
                    capture_output=True,
                    text=True,
                    timeout=900
                );
            } except subprocess.TimeoutExpired {
                lines.append("BUILD TIMEOUT");
                continue;
            }
            combined = (comp.stdout or "") + (comp.stderr or "");
            lines.append(f"build rc={comp.returncode}");
            for line in combined.splitlines() {
                if _keep(line) {
                    lines.append(f"  b| {line[:300]}");
                }
            }
            if comp.returncode != 0 or not os.path.exists(out_bin) {
                lines.append("  b| (tail) " + combined[-1200:].replace("\n", "\n  b| "));
                continue;
            }
            try {
                ran = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
            } except subprocess.TimeoutExpired {
                lines.append("RUN TIMEOUT");
                continue;
            }
            lines.append(f"run rc={ran.returncode}");
            lines.append("  stdout: " + repr(ran.stdout[-600:]));
            lines.append("  stderr: " + repr(ran.stderr[-600:]));
        }
    }
    return "\n".join(lines);
}

test "callable probe report" {
    assert False , "\n" + probe_report();
}
