"""Tests for the lazy Jac import finder (_jac_finder).

These exercise the path the single binary takes at startup: a clean interpreter
where nobody has imported jaclang yet, relying solely on
`_jac_finder.install()` (run by the launcher's BOOT_SRC) to make .jac modules
importable without paying the full jaclang bootstrap up front.
"""

import from tests.support { COMPILER_SITE }
import os;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from subprocess { run }


"""Run a snippet in a clean interpreter where jaclang is not pre-imported."""
def _run_clean(snippet: str) -> any {
    return run([sys.executable, "-c", snippet], capture_output=True, text=True);
}


test "lazy finder loads a .jac submodule of a no-__init__ package" {
    if os.environ.get("JAC_STANDALONE") {
        # This asserts the clean-room pip/.pth precondition (jaclang not yet
        # imported). Under the single binary jaclang IS the runtime and is always
        # loaded, so the precondition cannot hold -- the scenario is pip-only.
        testskip("pip/.pth clean-room scenario is N/A under the single binary");
    }
    # The package directory has no __init__.py, so `import pkg.mod` must resolve
    # a .jac submodule without anything having imported jaclang first -- exactly
    # what the lazy _jac_finder enables.
    tmp_path = tempfile.mkdtemp();
    try {
        pkg = Path(tmp_path) / "demopkg";
        pkg.mkdir();
        (pkg / "greet.jac").write_text(
            'def hello() -> str { return "hi-from-jac"; }\n'
        );

        snippet = (
            f"import sys; sys.path.insert(0, {COMPILER_SITE!r}); sys.path.insert(0, "
            + repr(tmp_path)
            + ");"
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
            f"import sys; sys.path.insert(0, {COMPILER_SITE!r}); sys.path.insert(0, "
            + repr(tmp_path)
            + ");"
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

test "compiler selection rejects a source checkout" {
    import _jac_finder;
    import from unittest.mock { patch }
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "jaclang").mkdir();
        with patch.dict(os.environ, {"JAC_COMPILER_IMAGE": directory}) {
            with testraises(RuntimeError) {
                _jac_finder.apply_compiler_image();
            }
        }
    }
}

test "compiler selection cannot replace an already loaded compiler" {
    import _jac_finder;
    import from unittest.mock { patch }
    with tempfile.TemporaryDirectory() as directory {
        manifest_dir = Path(directory) / "jaclang" / "_precompiled";
        manifest_dir.mkdir(parents=True);
        (manifest_dir / "MANIFEST.json").write_text("{}");
        with patch.dict(os.environ, {"JAC_COMPILER_IMAGE": directory}) {
            with testraises(RuntimeError) {
                _jac_finder.apply_compiler_image();
            }
        }
    }
}
