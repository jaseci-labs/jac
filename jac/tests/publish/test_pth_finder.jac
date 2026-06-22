"""Tests for the .pth-installed lazy Jac import finder (_jac_finder).

These exercise the path a pip-installed Jac wheel takes: a clean interpreter
where nobody has imported jaclang yet, relying solely on the jaclang.pth shim
to make .jac modules importable.
"""

import os;
import sys;
import tempfile;
import shutil;
import pytest;
import from pathlib { Path }
import from subprocess { run }


"""Run a snippet in a clean interpreter where jaclang is not pre-imported."""
def _run_clean(snippet: str) -> object {
    return run([sys.executable, "-c", snippet], capture_output=True, text=True);
}


test "lazy finder loads a .jac submodule of a no-__init__ package" {
    if os.environ.get("JAC_STANDALONE") {
        # This asserts the clean-room pip/.pth precondition (jaclang not yet
        # imported). Under the single binary jaclang IS the runtime and is always
        # loaded, so the precondition cannot hold -- the scenario is pip-only.
        pytest.skip("pip/.pth clean-room scenario is N/A under the single binary");
    }
    # Mirrors a pip-installed Jac wheel: the package directory has no
    # __init__.py, so `import pkg.mod` must resolve a .jac submodule without
    # anything having imported jaclang first -- exactly what jaclang.pth enables.
    tmp_path = tempfile.mkdtemp();
    try {
        pkg = Path(tmp_path) / "demopkg";
        pkg.mkdir();
        (pkg / "greet.jac").write_text(
            'def hello() -> str { return "hi-from-jac"; }\n'
        );

        snippet = (
            "import sys; sys.path.insert(0, " + repr(tmp_path) + ");"
            "import _jac_finder; _jac_finder.install();"
            "assert 'jaclang' not in sys.modules, 'jaclang imported before first .jac use';"
            "import demopkg.greet;"
            "print(demopkg.greet.hello());"
        );
        result = _run_clean(snippet);

        assert result.returncode == 0 , result.stderr;
        assert "hi-from-jac" in result.stdout;
    } finally {
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "lazy finder loads a top-level .jac module" {
    # Regression guard: the top-level import path must keep working.
    tmp_path = tempfile.mkdtemp();
    try {
        (Path(tmp_path) / "solo.jac").write_text(
            'def ping() -> str { return "pong"; }\n'
        );

        snippet = (
            "import sys; sys.path.insert(0, " + repr(tmp_path) + ");"
            "import _jac_finder; _jac_finder.install();"
            "import solo;"
            "print(solo.ping());"
        );
        result = _run_clean(snippet);

        assert result.returncode == 0 , result.stderr;
        assert "pong" in result.stdout;
    } finally {
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}
