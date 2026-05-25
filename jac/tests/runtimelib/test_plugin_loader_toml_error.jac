"""Plugin-loader / CLI error handling for malformed jac.toml.

Two layers:
  - Library bootstrap (`import jaclang`, `get_disabled_plugins`) MUST NOT
    exit on parse failure - that would break notebooks, scripts, and
    `jac format` itself. It logs a single stderr warning and continues
    with an empty plugin disable list.
  - The CLI (`jac <command>`) MUST exit 2 with an actionable banner so
    the user fixes the file instead of seeing N misleading "Install
    the missing package" warnings."""

import os;
import subprocess;
import sys;
import tempfile;


"""Run a subprocess under a temp dir containing a malformed jac.toml.
Returns CompletedProcess. PYTHONPATH is scrubbed so the test result is
the same on developer machines (where `jac/` may be on sys.path and
hit sitecustomize.py) and CI."""
def _run_with_broken_toml(argv: list) -> "subprocess.CompletedProcess" {
    with tempfile.TemporaryDirectory() as tmpdir {
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            # Missing closing quote - real-world parse failure.
            f.write('[plugins.scale.microservices]\nhost = "broken\n');
        }
        env = os.environ.copy();
        env.pop("PYTHONPATH", None);
        env["PYTHONNOUSERSITE"] = "1";
        return subprocess.run(
            argv, cwd=tmpdir, env=env, capture_output=True, text=True, timeout=60
        );
    }
}


test "library: `import jaclang` with malformed jac.toml succeeds with warning" {
    result = _run_with_broken_toml(
        [sys.executable, "-c", "import jaclang; print('ok')"]
    );
    assert result.returncode == 0 , (
        f"import jaclang must NOT exit on malformed jac.toml; got rc={result.returncode}\n"
        f"stdout: {result.stdout}\nstderr: {result.stderr}"
    );
    assert "ok" in result.stdout;
    # The warning explains why config is being ignored.
    assert "jac.toml" in result.stderr;
    assert "malformed" in result.stderr.lower();
    # And the misleading "Install the missing package" hint must NOT be
    # the first / only thing the user sees.
    assert "jac.toml" in result.stderr.split("Install the missing package")[0];
}


test "cli: `jac` command with malformed jac.toml exits 2 with banner" {
    result = _run_with_broken_toml([sys.executable, "-m", "jaclang", "--version"]);
    assert result.returncode == 2 , (
        f"expected jac CLI exit 2 on malformed jac.toml, got {result.returncode}\n"
        f"stdout: {result.stdout}\nstderr: {result.stderr}"
    );
    assert "jac.toml" in result.stderr;
    assert "malformed" in result.stderr.lower();
    assert "fix" in result.stderr.lower();
}
