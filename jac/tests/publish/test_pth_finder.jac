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
def _fake_source(stubs: bool = True) -> str {
    src = tempfile.mkdtemp(prefix="jac-devsrc-");
    os.makedirs(os.path.join(src, "jaclang"), exist_ok=True);
    if stubs {
        # What `zig build fetch-typeshed` leaves behind: the finder reroutes
        # into a checkout only once its typeshed stdlib is materialized.
        stdlib = os.path.join(src, "jaclang", "vendor", "typeshed", "stdlib");
        os.makedirs(stdlib, exist_ok=True);
        Path(os.path.join(stdlib, "builtins.pyi")).write_text("class object: ...\n");
    }
    return src;
}

"""Load the REPO's _jac_finder by path: the copy in sys.modules is the
binary's materialized runtime file, not the tree under test."""
def _load_finder -> any {
    import importlib.util;
    import from tests.support { JAC_ROOT }
    finder_path = os.path.join(JAC_ROOT, "_jac_finder.py");
    spec = importlib.util.spec_from_file_location(
        "_jac_finder_under_test", finder_path
    );
    assert spec is not None;
    mod = importlib.util.module_from_spec(spec);
    loader = spec.loader;
    assert loader is not None;
    loader.exec_module(mod);
    return mod;
}

"""Run apply_dev_source_override with the baked link, the `[dev]` table and the
inherited handoff controlled per call (`inherited` None means a top-level
process, "" a parent pinned to the bundled compiler), restoring sys.path and
the handoff afterwards; returns sys.path[0] and the compiler source the
override handed on."""
def _override_result(
    baked: (str | None), toml_src: (str | None), inherited: (str | None) = None
) -> tuple[str, str] {
    import json;
    _jac_finder = _load_finder();
    import from unittest.mock { patch }
    saved_path = list(sys.path);
    saved_handoff = os.environ.get(_jac_finder.HANDOFF_ENV);
    try {
        if inherited is None {
            os.environ.pop(_jac_finder.HANDOFF_ENV, None);
        } else {
            os.environ[_jac_finder.HANDOFF_ENV] = json.dumps(
                {"compiler_source": inherited}
            );
        }
        with patch.object(_jac_finder, "_baked_source_dir", return_value=baked), patch.object(
            _jac_finder, "_dev_table", return_value=(toml_src, False)
        ) {
            _jac_finder.apply_dev_source_override();
        }
        return (sys.path[0], str(_jac_finder.handoff().get("compiler_source")));
    } finally {
        sys.path[:] = saved_path;
        if saved_handoff is None {
            os.environ.pop(_jac_finder.HANDOFF_ENV, None);
        } else {
            os.environ[_jac_finder.HANDOFF_ENV] = saved_handoff;
        }
    }
}

test "a top-level jac prefers the repo's own toml stanza over a baked link" {
    # A binary linked to checkout A, run inside checkout B whose jac.toml
    # declares [dev] jaclang_source: B's own compiler must win -- that is
    # the whole point of the per-repo dev stanza. The baked link is the
    # fallback for directories with no stanza in scope.
    baked = _fake_source();
    toml_src = _fake_source();
    try {
        assert _override_result(baked, toml_src) == (toml_src, toml_src) , "the nearest jac.toml [dev] stanza must beat the binary's baked link";
        assert _override_result(baked, None) == (baked, baked) , "with no toml stanza in scope, the baked link still applies";
    } finally {
        shutil.rmtree(baked, ignore_errors=True);
        shutil.rmtree(toml_src, ignore_errors=True);
    }
}

test "a child jac runs its parent's compiler whatever its cwd" {
    # A rerouted jac hands its children its compiler; a child spawned from any
    # cwd (a nacompile into a temp dir, a test running inside another
    # project) stays on that compiler, so a process tree never mixes two.
    parent_src = _fake_source();
    baked = _fake_source();
    toml_src = _fake_source();
    try {
        assert _override_result(None, None, inherited=parent_src)
            == (parent_src, parent_src);
        assert _override_result(baked, toml_src, inherited=parent_src)[0]
            == parent_src , "the parent's compiler must beat both the child's stanza and the baked link";
    } finally {
        shutil.rmtree(parent_src, ignore_errors=True);
        shutil.rmtree(baked, ignore_errors=True);
        shutil.rmtree(toml_src, ignore_errors=True);
    }
}

test "a tree pinned to the bundled compiler stays there but keeps a linked binary alive" {
    baked = _fake_source();
    toml_src = _fake_source();
    try {
        (first, handed) = _override_result(None, toml_src, inherited="");
        assert first != toml_src and handed == "" , "a bundled parent's child must not reroute into a [dev] stanza";
        # A linked binary has no bundled jaclang: its baked path applies even
        # in a pinned tree, or `import jaclang` bricks.
        assert _override_result(baked, toml_src, inherited="")[0] == baked;
    } finally {
        shutil.rmtree(baked, ignore_errors=True);
        shutil.rmtree(toml_src, ignore_errors=True);
    }
}

test "a bare checkout (no typeshed stubs) is refused as a dev source; a baked link never is" {
    # A fresh clone carries jaclang/ but not the gitignored typeshed stdlib
    # (zig build fetch-typeshed materializes it), and rerouting into it breaks
    # the first compile with "Stub file not found at .../typing.pyi" -- a
    # released binary run inside a repo whose jac.toml ships a [dev] stanza
    # for its contributors. The top-level process refuses such a tree with a
    # note naming the fix; the baked link still applies, because a linked
    # binary has no bundled compiler to fall back on. A child runs whatever
    # the top of its tree chose: an inherited record is not re-judged.
    import io;
    import from contextlib { redirect_stderr }
    bare = _fake_source(stubs=False);
    baked = _fake_source();
    bare_baked = _fake_source(stubs=False);
    try {
        err = io.StringIO();
        with redirect_stderr(err) {
            assert _override_result(None, bare)[0] != bare , "a checkout without typeshed stubs must not be rerouted into";
        }
        assert "typeshed" in err.getvalue() and "fetch-typeshed" in err.getvalue() , f"the refusal must say what is missing and how to fix it, got: {err.getvalue()!r}";
        assert _override_result(baked, bare)[0] == baked , "a refused stanza falls through to the baked link";
        assert _override_result(None, None, inherited=bare)[0] == bare , "a child runs the compiler the top of its tree chose";
        assert _override_result(bare_baked, None)[0] == bare_baked , "a baked link is never refused: a linked binary has nothing else to run";
    } finally {
        shutil.rmtree(bare, ignore_errors=True);
        shutil.rmtree(baked, ignore_errors=True);
        shutil.rmtree(bare_baked, ignore_errors=True);
    }
}
