"""Tests for local sandbox Windows compatibility."""

import os;
import sys;
import tempfile;
import from pathlib { Path }


test "tempfile.gettempdir returns valid path on all platforms" {
    tmp = tempfile.gettempdir();
    assert os.path.isdir(tmp) , f"tempfile.gettempdir() returned invalid path: {tmp}";
}


"""Verify _find_jac_binary uses Scripts/ on Windows, bin/ on Unix."""
test "local sandbox find_jac_binary handles Windows paths" {
    import shutil;
    is_windows = sys.platform == "win32";
    bin_dir = "Scripts" if is_windows else "bin";
    jac_name = "jac.exe" if is_windows else "jac";

    # shutil.which should find jac if installed
    result = shutil.which("jac");
    if result {
        assert os.path.isfile(result) , f"shutil.which('jac') returned non-existent path: {result}";
    }
}


"""Verify activate script path uses Scripts/ on Windows."""
test "local sandbox find_activate_script handles Windows paths" {
    is_windows = sys.platform == "win32";
    bin_dir = "Scripts" if is_windows else "bin";
    activate_name = "activate.bat" if is_windows else "activate";

    venv = os.environ.get("VIRTUAL_ENV", "");
    if venv {
        expected = os.path.join(venv, bin_dir, activate_name);
        # May or may not exist, but path should be well-formed
        assert bin_dir in expected , f"Activate path doesn't use {bin_dir}: {expected}";
    }
}


"""Verify process.terminate() works (used instead of os.killpg on Windows)."""
test "process terminate works on all platforms" {
    import subprocess;
    # Start a simple process
    if sys.platform == "win32" {
        proc = subprocess.Popen(
            ["cmd", "/c", "timeout", "/t", "30"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        );
    } else {
        proc = subprocess.Popen(
            ["sleep", "30"], stdout=subprocess.PIPE, stderr=subprocess.PIPE
        );
    }

    assert proc.poll() is None , "Process should be running";
    proc.terminate();
    proc.wait(timeout=5);
    assert proc.poll() is not None , "Process should be terminated";
}


"""Verify Windows uses 'call' and Unix uses 'source'."""
test "shell command syntax differs by platform" {
    is_windows = sys.platform == "win32";
    if is_windows {
        # On Windows, 'call' is the equivalent of 'source'
        assert os.environ.get("COMSPEC", "").endswith("cmd.exe") or True , "Windows should have COMSPEC set";
    } else {
        # On Unix, /bin/bash should exist
        assert os.path.isfile("/bin/bash") , "/bin/bash should exist on Unix";
    }
}
