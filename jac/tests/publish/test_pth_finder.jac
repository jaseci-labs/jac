"""Tests for the lazy Jac import finder (_jac_finder).

These exercise the path the single binary takes at startup: a clean interpreter
where nobody has imported jaclang yet, relying solely on
`_jac_finder.install()` (run by the launcher's BOOT_SRC) to make .jac modules
importable without paying the full jaclang bootstrap up front.
"""

import os;
import sys;
import tempfile;
import shutil;
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
            "import sys; sys.path.insert(0, "
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
            "import sys; sys.path.insert(0, "
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

"""Make a fake compiler source dir (contains a jaclang/ package dir)."""
def _fake_source -> str {
    src = tempfile.mkdtemp(prefix="jac-devsrc-");
    os.makedirs(os.path.join(src, "jaclang"), exist_ok=True);
    return src;
}

"""Load the REPO's _jac_finder by path: the copy in sys.modules is the
binary's materialized runtime file, not the tree under test."""
def _load_finder -> object {
    import importlib.util;
    import from tests.support { JAC_ROOT }
    finder_path = os.path.join(JAC_ROOT, "_jac_finder.py");
    spec = importlib.util.spec_from_file_location(
        "_jac_finder_under_test", finder_path
    );
    mod = importlib.util.module_from_spec(spec);
    spec.loader.exec_module(mod);
    return mod;
}

"""Run apply_dev_source_override with baked/toml sources patched, restoring
sys.path and env afterwards; returns the resulting sys.path[0]."""
def _override_result(
    baked: (str | None),
    toml_src: (str | None),
    no_dev_env: bool = False,
    inherited: (str | None) = None
) -> str {
    _jac_finder = _load_finder();
    import from unittest.mock { patch }
    saved_path = list(sys.path);
    saved_dev = os.environ.get("JAC_DEV_SOURCE");
    saved_pre = os.environ.get("JAC_NO_PRECOMPILE");
    saved_no_dev = os.environ.get("JAC_NO_DEV_SOURCE");
    try {
        # CI's binary jobs export JAC_NO_DEV_SOURCE=1 globally, which would
        # suppress the toml loop under test -- so the flag is controlled
        # HERE, per call, never inherited from the environment. The same goes
        # for JAC_DEV_SOURCE: a rerouted `jac test` exports it, and the finder
        # now reads it as a parent's source, so each call sets it explicitly.
        if no_dev_env {
            os.environ["JAC_NO_DEV_SOURCE"] = "1";
        } else {
            os.environ.pop("JAC_NO_DEV_SOURCE", None);
        }
        if inherited is not None {
            os.environ["JAC_DEV_SOURCE"] = inherited;
        } else {
            os.environ.pop("JAC_DEV_SOURCE", None);
        }
        with patch.object(_jac_finder, "_baked_source_dir", return_value=baked), patch.object(
            _jac_finder, "_dev_source_from_toml", return_value=toml_src
        ) {
            _jac_finder.apply_dev_source_override();
        }
        return sys.path[0];
    } finally {
        sys.path[:] = saved_path;
        if saved_dev is None {
            os.environ.pop("JAC_DEV_SOURCE", None);
        } else {
            os.environ["JAC_DEV_SOURCE"] = saved_dev;
        }
        if saved_pre is None {
            os.environ.pop("JAC_NO_PRECOMPILE", None);
        }
        if saved_no_dev is None {
            os.environ.pop("JAC_NO_DEV_SOURCE", None);
        } else {
            os.environ["JAC_NO_DEV_SOURCE"] = saved_no_dev;
        }
    }
}

test "dev override prefers the repo's own toml stanza over a baked link" {
    # A binary linked to checkout A, run inside checkout B whose jac.toml
    # declares [dev] jaclang_source: B's own compiler must win -- that is
    # the whole point of the per-repo dev stanza. The baked link is the
    # fallback for directories with no stanza in scope.
    baked = _fake_source();
    toml_src = _fake_source();
    try {
        assert _override_result(baked, toml_src) == toml_src , "the nearest jac.toml [dev] stanza must beat the binary's baked link";
        assert _override_result(baked, None) == baked , "with no toml stanza in scope, the baked link still applies";
    } finally {
        shutil.rmtree(baked, ignore_errors=True);
        shutil.rmtree(toml_src, ignore_errors=True);
    }
}

test "a child jac inherits its parent's dev source when no stanza is in scope" {
    # A rerouted jac exports JAC_DEV_SOURCE; a child it spawns from any cwd (a
    # nacompile into a temp dir) must stay on that compiler rather than fall
    # back to the bundled copy. The repo's own stanza still wins, and
    # JAC_NO_DEV_SOURCE switches the inherited loop off like the toml one.
    parent_src = _fake_source();
    baked = _fake_source();
    toml_src = _fake_source();
    try {
        assert _override_result(None, None, inherited=parent_src) == parent_src , "an inherited JAC_DEV_SOURCE must reroute a child with no stanza in scope";
        assert _override_result(baked, None, inherited=parent_src) == parent_src , "the parent's source must beat the baked link";
        assert _override_result(baked, toml_src, inherited=parent_src) == toml_src , "the nearest jac.toml [dev] stanza must beat an inherited source";
        assert _override_result(baked, None, no_dev_env=True, inherited=parent_src)
            == baked , "JAC_NO_DEV_SOURCE must suppress the inherited loop, not the baked link";
    } finally {
        shutil.rmtree(parent_src, ignore_errors=True);
        shutil.rmtree(baked, ignore_errors=True);
        shutil.rmtree(toml_src, ignore_errors=True);
    }
}

test "JAC_NO_DEV_SOURCE disables the toml loop but keeps a linked binary alive" {
    baked = _fake_source();
    toml_src = _fake_source();
    try {
        # A linked binary has no bundled jaclang: the baked path must apply
        # even under JAC_NO_DEV_SOURCE, or `import jaclang` bricks.
        assert _override_result(baked, toml_src, no_dev_env=True) == baked , "JAC_NO_DEV_SOURCE must suppress the toml loop, not the baked link";
    } finally {
        shutil.rmtree(baked, ignore_errors=True);
        shutil.rmtree(toml_src, ignore_errors=True);
    }
}
