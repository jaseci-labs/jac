"""Guards #7047: the single binary must not leak its embedded-interpreter
configuration (PYTHONHOME/PYTHONPATH) into the process environment.

The launcher used to export PYTHONHOME/PYTHONPATH for the bundled CPython via
setenv, so every subprocess inherited them; any python-based child (`aws` EKS
exec-credentials, plain `python3`, ...) then adopted the jac runtime as its
home, could not find its own stdlib, and died with "Fatal Python error: Failed
to import encodings module". Interpreter config now flows through the PEP 741
init config, never the environment.
"""

import os;
import shutil;
import subprocess;
import sys;
import pytest;


test "embedded interpreter config is not in the environment" {
    if not os.environ.get("JAC_STANDALONE") {
        # Under pip-installed jaclang the environment is the user's own (a dev
        # may legitimately export PYTHONPATH); only the binary must be clean.
        pytest.skip("environment hermeticity is a single-binary guarantee");
    }
    # A user may legitimately have their own PYTHONHOME/PYTHONPATH exported
    # (the fix passes those through untouched), so assert specifically that the
    # LAUNCHER's values are absent: the leak was exactly PYTHONHOME pointing at
    # the bundled runtime (sys.prefix) and PYTHONPATH carrying its dirs.
    assert os.environ.get("PYTHONHOME") != sys.prefix;
    assert sys.prefix not in os.environ.get("PYTHONPATH", "");
}


test "a foreign python3 child survives being spawned from jac" {
    if not os.environ.get("JAC_STANDALONE") {
        pytest.skip("guards the single binary's env; pip runs inherit the user's env");
    }
    py3 = shutil.which("python3");
    if not py3 {
        pytest.skip("no python3 on PATH to spawn");
    }
    # Default-inherited environment on purpose -- that is exactly the leak path.
    r = subprocess.run(
        [py3, "-c", "import encodings; print('child ok')"],
        capture_output=True,
        text=True
    );
    assert r.returncode == 0 , f"python3 child died: {r.stderr[:200]}";
    assert "child ok" in r.stdout;
}
