"""The KEDA observer e2e judges a recorded scale cycle; these feed it recordings
through its --check mode, so the judgement runs without a cluster."""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob SCRIPT = str(Path(__file__).parent / "keda_observer_real_e2e.sh"),
     _IDLED_AT_DEPLOY = (
         "echo-deployment activating -> deactivating reason=ScalingToZero\n"
         "echo-deployment deactivating -> inactive reason=Idle\n"
     ),
     _ACTIVE_AT_DEPLOY = (
         "echo-deployment activating -> active reason=-\n"
         "echo-deployment active -> deactivating reason=ScalingToZero\n"
         "echo-deployment deactivating -> inactive reason=Idle\n"
     ),
     _WAKE_TO_DEACTIVATING = (
         "echo-deployment inactive -> activating reason=RollingOut\n"
         "echo-deployment activating -> active reason=-\n"
         "echo-deployment active -> deactivating reason=ScalingToZero\n"
     ),
     _BACK_TO_INACTIVE = "echo-deployment deactivating -> inactive reason=Idle\n";


test "the judged cycle is the wake out of inactive, wherever the deploy settled" {
    for (label, recording, rc, expected) in [
        (
            "idled at deploy (run 37130148111)",
            _IDLED_AT_DEPLOY + _WAKE_TO_DEACTIVATING + _BACK_TO_INACTIVE,
            0,
            "observed states: deactivating inactive activating active deactivating inactive"
        ),
        (
            "active at deploy",
            _ACTIVE_AT_DEPLOY + _WAKE_TO_DEACTIVATING + _BACK_TO_INACTIVE,
            0,
            "observed states: active deactivating inactive activating active deactivating inactive"
        ),
        (
            "stopped before the return to inactive (run 37752519654)",
            _IDLED_AT_DEPLOY + _WAKE_TO_DEACTIVATING,
            1,
            "never observed a return to 'inactive' after 'active'"
        )
    ] {
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f {
            f.write(recording);
            path = f.name;
        }
        try {
            result = subprocess.run(
                ["bash", SCRIPT, "--check", path], capture_output=True, text=True
            );
        } finally {
            os.unlink(path);
        }
        assert result.returncode == rc , f"{label}: {result.stdout}{result.stderr}";
        assert expected in result.stdout + result.stderr , f"{label}: {result.stdout}{result.stderr}";
    }
}
