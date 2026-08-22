"""P3 object-core runtime parity driver (TODO.md item 5 / FIXME M11).

Runs ``layer0_replay_p3_runtime_gate.jac`` via ``jac run`` so Layer-1 replay
probes execute on a clean ceval slate.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
GATE_JAC = REPO_ROOT / "jac-py" / "jacpython" / "layer0_replay_p3_runtime_gate.jac"


def _resolve_jac() -> Path | None:
    """$JAC override, then PATH (CI installs jac-kit), then the dev venv."""
    env_bin = os.environ.get("JAC")
    if env_bin:
        return Path(env_bin)
    on_path = shutil.which("jac")
    if on_path:
        return Path(on_path)
    venv_bin = REPO_ROOT / ".venv" / "bin" / "jac"
    return venv_bin if venv_bin.is_file() else None


class P3RuntimeGate(unittest.TestCase):
    def test_runtime_probes_match_cpython(self) -> None:
        env = os.environ.copy()
        jac_src = REPO_ROOT / "jac"
        existing = env.get("PYTHONPATH", "")
        if str(jac_src) not in existing.split(os.pathsep):
            env["PYTHONPATH"] = (
                str(jac_src) if not existing else f"{jac_src}{os.pathsep}{existing}"
            )
        env["JAC_DEV_SOURCE"] = str(jac_src)
        cpython = env.get("JACPYTHON_CPYTHON")
        if not cpython:
            self.skipTest("JACPYTHON_CPYTHON not set")
        jac_bin = _resolve_jac()
        if jac_bin is None:
            self.skipTest("jac binary not found (set $JAC or install jac-kit)")
        proc = subprocess.run(
            [str(jac_bin), "run", str(GATE_JAC)],
            cwd=REPO_ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        detail = (proc.stderr or proc.stdout or "jac run failed").strip()
        self.assertEqual(
            proc.returncode,
            0,
            msg=detail,
        )
        self.assertIn("P3 runtime probes: all stems OK", proc.stdout)


if __name__ == "__main__":
    unittest.main()
