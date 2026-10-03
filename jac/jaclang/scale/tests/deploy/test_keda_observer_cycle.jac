"""The KEDA observer e2e judges a recorded scale cycle; these feed it recordings
from real CI runs through its --check mode, so the judgement runs without a cluster."""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob SCRIPT = str(Path(__file__).parent / "keda_observer_real_e2e.sh"),
     _DEPLOY_FLAP_THEN_CYCLE = (
         "echo-deployment activating -> deactivating reason=ScalingToZero rv=1924\n"
         "echo-deployment deactivating -> inactive reason=Idle rv=1941\n"
         "echo-deployment inactive -> activating reason=RollingOut rv=2894\n"
         "echo-deployment activating -> active reason=- rv=3136\n"
         "echo-deployment active -> deactivating reason=ScalingToZero rv=3331\n"
         "echo-deployment deactivating -> inactive reason=Idle rv=3385\n"
     ),
     _STOPPED_BEFORE_INACTIVE = (
         "echo-deployment inactive -> activating reason=RollingOut rv=1767\n"
         "echo-deployment activating -> active reason=- rv=1962\n"
         "echo-deployment active -> deactivating reason=ScalingToZero rv=2132\n"
     ),
     _DEGRADED_IN_CYCLE = (
         "echo-deployment inactive -> activating reason=RollingOut rv=10\n"
         "echo-deployment activating -> active reason=- rv=11\n"
         "echo-deployment active -> degraded reason=ScalingActiveFalse rv=12\n"
         "echo-deployment degraded -> inactive reason=Idle rv=13\n"
     );


def _check(transitions: str) -> subprocess.CompletedProcess {
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f {
        f.write(transitions);
        path = f.name;
    }
    try {
        return subprocess.run(
            ["bash", SCRIPT, "--check", path], capture_output=True, text=True
        );
    } finally {
        os.unlink(path);
    }
}


test "a deploy-time flap before the cycle does not cut the cycle off" {
    result = _check(_DEPLOY_FLAP_THEN_CYCLE);
    assert result.returncode == 0 , result.stderr;
    assert "ok: no degraded transition" in result.stdout , result.stdout;
}


test "a recording that never returns to inactive after active fails" {
    result = _check(_STOPPED_BEFORE_INACTIVE);
    assert result.returncode == 1 , result.stdout;
    assert "never observed a return to 'inactive' after 'active'" in result.stderr , result.stderr;
}


test "a degraded transition during the cycle fails" {
    result = _check(_DEGRADED_IN_CYCLE);
    assert result.returncode == 1 , result.stdout;
    assert "a healthy cycle reported degraded" in result.stderr , result.stderr;
}


test "an empty recording fails" {
    result = _check("");
    assert result.returncode == 1 , result.stdout;
    assert "recorded no transitions" in result.stderr , result.stderr;
}
