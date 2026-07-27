"""Integration tests for the format cache behind ``jac fmt`` (Seam B).

These exercise the cache through the public ``analysis.format`` command. The
spec under test is "an already-formatted file costs zero formatter work on
the second run". Because a cache hit and a genuine no-op format produce
identical output, the skip is observed via an injectable ``cache_stats``
out-dict on ``format()`` (single-file runs stay in-process, so stats are exact).

Each project test gets a temp dir with a ``jac.toml`` so config discovery
resolves a real cache dir (``<tmp>/.jac/cache``). The project config
singleton is reset around every call, mirroring ``test_precommit.jac``.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from io { StringIO }
import from contextlib { redirect_stdout }

import from jaclang.cli.commands.analysis { format as fmt_cmd }
import from jaclang.cli.commands.analysis { precommit }
import from jaclang.project { config as config_mod }

glob CLEAN = "def f(x: int) -> int {\n    return x + 1;\n}\n",
     NEEDS_FMT = "def f(x:int)->int{return x+1;}\n",
     BROKEN = "def f(x: int) -> int {\n    return x + ;\n}\n",
     CLEAN_MOD = "# top-level comment\nobj Foo {\n    def bar -> int;\n}\n",
     CLEAN_MOD_V2 = "# top-level comment v2\nobj Foo {\n    def bar -> int;\n}\n",
     CLEAN_IMPL = "def foo -> int {\n    return 42;\n}\n",
     NEEDS_FMT_IMPL = "def foo->int{return 42;}\n";

"""Make a temp project (with jac.toml) and return its path."""
def make_project -> str {
    repo = tempfile.mkdtemp(prefix="fmtcache-it-");
    (Path(repo) / "jac.toml").write_text('[project]\nname = "ft"\nversion = "0.0.1"\n');
    return repo;
}

"""Reset the config singleton; call before format()."""
def reset_state {
    config_mod._config = None;
    config_mod._config_explicit = False;
    config_mod._config_by_root = {};
}

test "second run on a clean file is a cache hit (formatter not invoked)" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(CLEAN);
        reset_state();
        stats1: dict = {};
        r1 = fmt_cmd([str(f)], cache=True, cache_stats=stats1);
        assert r1 == 0 , "clean file formats successfully";
        assert stats1.get("hits", 0) == 0 and stats1.get("misses", 0) == 1 , (
            f"first run must miss-and-cache, got {stats1}"
        );
        # Second identical run: same bytes => same key => HIT, no formatter work.
        reset_state();
        stats2: dict = {};
        r2 = fmt_cmd([str(f)], cache=True, cache_stats=stats2);
        assert r2 == 0;
        assert stats2.get("hits", 0) == 1 and stats2.get("misses", 0) == 0 , (
            f"second run on unchanged clean file must be a hit, got {stats2}"
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
        stats: dict = {};
        rc = fmt_cmd([str(f)], check=True, cache=True, cache_stats=stats);
        assert rc == 0 , "--check on a cached clean file must pass";
        assert stats.get("hits", 0) == 1 , f"--check must honour a clean hit, got {stats}";
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
        stats1: dict = {};
        r1 = fmt_cmd([str(f)], cache=True, cache_stats=stats1);
        assert r1 == 1 , "a changed file exits 1";
        assert f.read_text() == CLEAN , "the file must actually be rewritten";
        assert stats1.get("misses", 0) == 1 , f"first run is a miss, got {stats1}";
        # Run 2: disk now holds CLEAN -> must be a HIT (proves post-write caching).
        reset_state();
        stats2: dict = {};
        r2 = fmt_cmd([str(f)], cache=True, cache_stats=stats2);
        assert r2 == 0;
        assert stats2.get("hits", 0) == 1 , (
            f"after a successful write the clean result must be cached, got {stats2}"
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
        # It was examined and missed, but -- crucially -- NOT recorded clean,
        # so a second run must miss again (re-attempt formatting).
        reset_state();
        stats: dict = {};
        r2 = fmt_cmd([str(f)], cache=True, cache_stats=stats);
        assert stats.get("hits", 0) == 0 , (
            f"a failing file must never become a cache hit, got {stats}"
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
        stats: dict = {};
        r = fmt_cmd([str(f)], cache=True, cache_stats=stats);
        assert r == 1 , "changed content must miss and reformat (exit 1)";
        assert stats.get("hits", 0) == 0 and stats.get("misses", 0) == 1 , (
            f"content change must invalidate, got {stats}"
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
        stats: dict = {};
        fmt_cmd([str(f)], cache_stats=stats);  # no cache=True
        fmt_cmd([str(f)], cache_stats=stats);  # still no cache
        assert stats.get("hits", 0) == 0 and stats.get("misses", 0) == 0 , (
            f"without cache=True the stats dict must stay untouched, got {stats}"
        );
        # And no cache directory must have been created.
        assert not (Path(repo) / ".jac" / "cache").exists();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "cache works outside a project with default .jac/cache path" {
    # Docs promise default `.jac/cache/fmt-v1/` even without jac.toml.
    tmp = tempfile.mkdtemp(prefix="fmtcache-noproj-");
    old = os.getcwd();
    os.chdir(tmp);
    try {
        f = Path(tmp) / "solo.jac";
        f.write_text(CLEAN);
        reset_state();
        stats1: dict = {};
        r1 = fmt_cmd([str(f)], cache=True, cache_stats=stats1);
        assert r1 == 0;
        assert stats1.get("misses", 0) == 1 , f"first run must miss, got {stats1}";
        cache_root = Path(tmp) / ".jac" / "cache";
        assert cache_root.exists() , (
            f"without jac.toml, --cache must still create {cache_root}"
        );
        reset_state();
        stats2: dict = {};
        r2 = fmt_cmd([str(f)], cache=True, cache_stats=stats2);
        assert r2 == 0;
        assert stats2.get("hits", 0) == 1 , (
            f"second run outside a project must hit, got {stats2}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "to_screen with cache still prints formatted source" {
    # Cache hits must not suppress --to_screen output. Caching is disabled
    # for to_screen so the formatter always runs and prints.
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        reset_state();
        buf = StringIO();
        with redirect_stdout(buf) {
            stats: dict = {};
            rc = fmt_cmd([str(f)], to_screen=True, cache=True, cache_stats=stats);
            assert rc == 1 , "needs-fmt under to_screen still reports changed";
        }
        out = buf.getvalue();
        assert "def f" in out , (
            f"--to_screen --cache must print formatted source, got {out!r}"
        );
        assert stats.get("hits", 0) == 0 and stats.get("misses", 0) == 0 , (
            f"to_screen must disable caching, got {stats}"
        );
        # Disk unchanged under to_screen.
        assert f.read_text() == NEEDS_FMT;
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "lintfix cache does not share entries across excluded vs included paths" {
    # Identical content under an excluded path must not satisfy a non-excluded
    # path (and vice versa) when lintfix is on.
    repo = make_project();
    (Path(repo) / "jac.toml").write_text(
        '[project]\nname = "ft"\nversion = "0.0.1"\n\n' + '[check.lint]\nexclude = ["vendor/**"]\n'
    );
    old = os.getcwd();
    os.chdir(repo);
    try {
        src = Path(repo) / "src";
        vendor = Path(repo) / "vendor";
        src.mkdir();
        vendor.mkdir();
        (src / "a.jac").write_text(CLEAN);
        (vendor / "a.jac").write_text(CLEAN);
        reset_state();
        stats_v: dict = {};
        fmt_cmd([str(vendor / "a.jac")], lintfix=True, cache=True, cache_stats=stats_v);
        assert stats_v.get("misses", 0) == 1;
        # Formatting the included path must miss -- path is part of the key.
        reset_state();
        stats_s: dict = {};
        fmt_cmd([str(src / "a.jac")], lintfix=True, cache=True, cache_stats=stats_s);
        assert stats_s.get("hits", 0) == 0 and stats_s.get("misses", 0) == 1 , (
            f"excluded-path clean entry must not satisfy included path, got {stats_s}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "broken annex is never cached as clean" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "mod.jac";
        f.write_text("obj Foo {\n    def bar -> int;\n}\n");
        annex = Path(repo) / "mod.impl.jac";
        # Deliberately unparseable so the annex formatter reports errors.
        annex.write_text("this is {{{ not valid jac\n");
        reset_state();
        stats1: dict = {};
        fmt_cmd([str(f)], lintfix=True, cache=True, cache_stats=stats1);
        reset_state();
        stats2: dict = {};
        fmt_cmd([str(f)], lintfix=True, cache=True, cache_stats=stats2);
        assert stats2.get("hits", 0) == 0 , (
            f"a unit with a broken annex must never become a cache hit, got {stats2}"
        );
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
    # Config/lint discovery must still use the project logical path (jac.toml).
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
        stats1: dict = {};
        r1 = precommit(staged=True, verify=True, cache_stats=stats1);
        assert r1 == 0 , "clean staged blob must pass verify";
        assert stats1.get("hits", 0) == 0 and stats1.get("misses", 0) == 1 , (
            f"first verify misses, got {stats1}"
        );

        # Dirty ONLY the worktree copy (unstaged). The staged blob is still clean.
        f.write_text(NEEDS_FMT);

        # Run 2: staged dirty -> temp checkout of staged bytes -> same key -> HIT.
        reset_state();
        stats2: dict = {};
        r2 = precommit(staged=True, verify=True, cache_stats=stats2);
        assert r2 == 0 , "clean staged blob must still pass over a dirty worktree";
        assert stats2.get("hits", 0) == 1 and stats2.get("misses", 0) == 0 , (
            f"second verify must hit on staged bytes despite dirty worktree, got {stats2}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "precommit cache uses nested file config instead of root anchor" {
    import subprocess;
    repo = tempfile.mkdtemp(prefix="fmtcache-nested-pc-");
    subprocess.run(["git", "init", "-q", repo], check=True);
    (Path(repo) / "jac.toml").write_text(
        '[project]\nname = "root"\nversion = "0.0.1"\n\n'
        '[precommit]\ntypecheck = false\n'
    );
    nested = Path(repo) / "nested";
    nested.mkdir();
    nested_config = nested / "jac.toml";
    nested_config.write_text(
        '[project]\nname = "nested"\nversion = "0.0.1"\n\n'
        '[format]\noutfile = "nested-one"\n\n'
        '[precommit]\ntypecheck = false\n'
    );
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = nested / "a.jac";
        f.write_text(CLEAN);
        subprocess.run(["git", "add", "nested/a.jac"], check=True, cwd=repo);

        # The first verify records a clean entry using nested/jac.toml.
        reset_state();
        stats1: dict = {};
        r1 = precommit(staged=True, verify=True, cache_stats=stats1);
        assert r1 == 0;
        assert stats1.get("misses", 0) == 1 , (
            f"first nested verify must miss, got {stats1}"
        );

        # Changing only the nested config must invalidate that entry. If the
        # worker fingerprints cache_anchor (the repository root), this would
        # incorrectly be a hit under the unchanged root config.
        nested_config.write_text(
            '[project]\nname = "nested"\nversion = "0.0.1"\n\n'
            '[format]\noutfile = "nested-two"\n\n'
            '[precommit]\ntypecheck = false\n'
        );
        reset_state();
        stats2: dict = {};
        r2 = precommit(staged=True, verify=True, cache_stats=stats2);
        assert r2 == 0;
        assert stats2.get("hits", 0) == 0 and stats2.get("misses", 0) == 1 , (
            f"nested config changes must invalidate the cache, got {stats2}"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}

test "staged verify cache key covers tracked annex in the format unit" {
    # P1: when `precommit --staged --verify` builds a temp checkout from
    # staged targets, sibling .impl.jac/.test.jac annexes that were tracked
    # (committed) but not themselves staged were absent from the temp dir.
    # The cache key then covered only the main file, and a clean verdict
    # that skipped an unformatted annex could be recorded.  The fix ensures
    # tracked annexes are checked out into the temp directory so the
    # formatter verifies the full module unit and the cache key covers it.
    #
    # Proof: stage *only* the clean main file while a tracked annex in the
    # index is unformatted.  Without the fix the verify passes (annex
    # absent → skipped); with the fix it must fail (annex now verified).
    import subprocess;
    repo = tempfile.mkdtemp(prefix="fmtcache-annex-pc-");
    subprocess.run(["git", "init", "-q", repo], check=True);
    (Path(repo) / "jac.toml").write_text(
        '[project]\nname = "anx"\nversion = "0.0.1"\n\n'
        '[precommit]\ntypecheck = false\n'
    );
    old = os.getcwd();
    os.chdir(repo);
    try {
        import from jaclang.project { config as config_mod }
        f = Path(repo) / "mod.jac";
        annex = Path(repo) / "mod.impl.jac";
        f.write_text(CLEAN_MOD);
        annex.write_text(NEEDS_FMT_IMPL);
        subprocess.run(["git", "add", "mod.jac", "mod.impl.jac"], check=True, cwd=repo);
        subprocess.run(
            [
                "git",
                "-c",
                "user.email=fmtcache-test@example.com",
                "-c",
                "user.name=fmtcache-test",
                "commit",
                "-qm",
                "c0"
            ],
            check=True,
            cwd=repo
        );
        # Now the annex is tracked & clean-in-index but unformatted.
        # Stage ONLY the main file with a different clean content.
        f.write_text(CLEAN_MOD_V2);
        subprocess.run(["git", "add", "mod.jac"], check=True, cwd=repo);
        config_mod._config = None;
        config_mod._config_explicit = False;
        config_mod._config_by_root = {};
        rc = precommit(staged=True, verify=True);
        assert rc != 0 , (
            "staged verify must fail when a tracked annex is unformatted "
            "(the annex belongs to the module unit and the cache key must "
            "cover it)"
        );
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
}
