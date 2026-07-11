"""Integration tests for the format cache behind ``jac fmt`` (Seam B).

These exercise the cache through the public ``analysis.format`` command. The
spec under test is "an already-formatted file costs zero formatter work on
the second run". Because a cache hit and a genuine no-op format produce
identical output, the skip is observed via a best-effort run-stats hook on
the cache module (single-file runs stay in-process, so stats are exact).

Each test gets a temp project dir with a ``jac.toml`` so config discovery
resolves a real cache dir (``<tmp>/.jac/cache``). The project config
singleton is reset around every call, mirroring ``test_precommit.jac``.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }

import from jaclang.cli.commands.analysis { format as fmt_cmd }
import from jaclang.cli.commands.analysis { precommit }
import from jaclang.cli.format_cache {
    FormatCache,
    FORMAT_CACHE_SCHEMA_VERSION,
    reset_run_stats,
    run_stats
}
import from jaclang.project { config as config_mod }

glob CLEAN = "def f(x: int) -> int {\n    return x + 1;\n}\n",
     NEEDS_FMT = "def f(x:int)->int{return x+1;}\n",
     BROKEN = "def f(x: int) -> int {\n    return x + ;\n}\n";

"""Make a temp project (with jac.toml) and return its path."""
def make_project -> str {
    repo = tempfile.mkdtemp(prefix="fmtcache-it-");
    (Path(repo) / "jac.toml").write_text('[project]\nname = "ft"\nversion = "0.0.1"\n');
    return repo;
}

"""Reset the config singleton + per-run cache stats; call before format()."""
def reset_state {
    config_mod._config = None;
    config_mod._config_explicit = False;
    config_mod._config_by_root = {};
    reset_run_stats();
}

test "second run on a clean file is a cache hit (formatter not invoked)" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(CLEAN);
        reset_state();
        r1 = fmt_cmd([str(f)], cache=True);
        assert r1 == 0 , "clean file formats successfully";
        s1 = run_stats();
        assert s1["hits"] == 0 and s1["misses"] == 1 , (
            f"first run must miss-and-cache, got {s1}"
        );
        # Second identical run: same bytes => same key => HIT, no formatter work.
        reset_state();
        r2 = fmt_cmd([str(f)], cache=True);
        assert r2 == 0;
        s2 = run_stats();
        assert s2["hits"] == 1 and s2["misses"] == 0 , (
            f"second run on unchanged clean file must be a hit, got {s2}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "check mode returns 0 on a cached clean file via a hit" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(CLEAN);
        reset_state();
        fmt_cmd([str(f)], cache=True);  # populate
        reset_state();
        rc = fmt_cmd([str(f)], check=True, cache=True);
        assert rc == 0 , "--check on a cached clean file must pass";
        s = run_stats();
        assert s["hits"] == 1 , f"--check must honour a clean hit, got {s}";
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "a file that needed formatting is cached clean only after it is written" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        # Run 1: needs formatting -> miss -> formats -> writes -> now clean on disk.
        reset_state();
        r1 = fmt_cmd([str(f)], cache=True);
        assert r1 == 1 , "a changed file exits 1";
        assert f.read_text() == CLEAN , "the file must actually be rewritten";
        s1 = run_stats();
        assert s1["misses"] == 1 , f"first run is a miss, got {s1}";
        # Run 2: disk now holds CLEAN -> must be a HIT (proves post-write caching).
        reset_state();
        r2 = fmt_cmd([str(f)], cache=True);
        assert r2 == 0;
        s2 = run_stats();
        assert s2["hits"] == 1 , (
            f"after a successful write the clean result must be cached, got {s2}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "syntax errors are never cached as clean" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "broken.jac";
        f.write_text(BROKEN);
        reset_state();
        r1 = fmt_cmd([str(f)], cache=True);
        assert r1 == 1 , "a syntax-error file must fail";
        s1 = run_stats();
        # It was examined and missed, but -- crucially -- NOT recorded clean,
        # so a second run must miss again (re-attempt formatting).
        reset_state();
        r2 = fmt_cmd([str(f)], cache=True);
        s2 = run_stats();
        assert s2["hits"] == 0 , (
            f"a failing file must never become a cache hit, got {s2}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "content change invalidates the cache" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(CLEAN);
        reset_state();
        fmt_cmd([str(f)], cache=True);  # cached for CLEAN
        # Edit the file to need formatting: content changes -> key changes -> miss.
        f.write_text(NEEDS_FMT);
        reset_state();
        r = fmt_cmd([str(f)], cache=True);
        assert r == 1 , "changed content must miss and reformat (exit 1)";
        s = run_stats();
        assert s["hits"] == 0 and s["misses"] == 1 , (
            f"content change must invalidate, got {s}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "cache disabled by default for jac fmt (opt-in, Prettier-style)" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(CLEAN);
        reset_state();
        fmt_cmd([str(f)]);  # no cache=True
        fmt_cmd([str(f)]);  # still no cache
        s = run_stats();
        assert s["hits"] == 0 and s["misses"] == 0 , (
            f"without cache=True the stats hook must stay untouched, got {s}"
        );
        # And no cache directory must have been created.
        assert not (Path(repo) / ".jac" / "cache").exists();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "precommit cache keys on staged blob bytes, not the worktree" {
    # The format cache behind `jac precommit --staged --verify` must see the
    # STAGED bytes (the temp index checkout), never the worktree bytes. So a
    # second verify over a clean staged blob is a HIT even when the worktree
    # copy has since been dirtied -- the commit would still contain clean bytes.
    import subprocess;
    repo = tempfile.mkdtemp(prefix="fmtcache-pc-");
    subprocess.run(["git", "init", "-q", repo], check=True);
    # typecheck off isolates the FORMAT cache from the separate check step.
    (Path(repo) / "jac.toml").write_text(
        '[project]\nname = "pc"\nversion = "0.0.1"\n\n[precommit]\ntypecheck = false\n'
    );
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(CLEAN);
        subprocess.run(["git", "add", "a.jac"], check=True, cwd=repo);

        # Run 1: staged == worktree (clean) -> miss -> records clean.
        reset_state();
        r1 = precommit(staged=True, verify=True);
        assert r1 == 0 , "clean staged blob must pass verify";
        s1 = run_stats();
        assert s1["hits"] == 0 and s1["misses"] == 1 , f"first verify misses, got {s1}";

        # Dirty ONLY the worktree copy (unstaged). The staged blob is still clean.
        f.write_text(NEEDS_FMT);

        # Run 2: staged dirty -> temp checkout of staged bytes -> same key -> HIT.
        reset_state();
        r2 = precommit(staged=True, verify=True);
        assert r2 == 0 , "clean staged blob must still pass over a dirty worktree";
        s2 = run_stats();
        assert s2["hits"] == 1 and s2["misses"] == 0 , (
            f"second verify must hit on staged bytes despite dirty worktree, got {s2}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}
