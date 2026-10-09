"""Exit-code contract tests for ``jac fmt`` (issue #8536).

``jac fmt`` used to exit 1 whenever it reformatted anything
(``if changed_files > 0 { return 1; }``), conflating "made changes" with
"error" and breaking ``jac fmt . && jac test`` pipelines. Standard formatter
convention (black, gofmt, prettier) is exit 0 after successful reformatting,
with nonzero reserved for operational failures; CI gating belongs to
``--check`` (exit 1 if any file *would* change, no writes).

The observable contract pinned here:

- plain reformatting: exit 0 AND the file is rewritten on disk;
- already-clean input: exit 0;
- ``--check`` on unformatted input: exit 1, disk bytes unchanged;
- ``--to_screen`` on unformatted input: exit 0, formatted source printed,
  disk unchanged;
- ``--lintfix`` where every issue is auto-fixable: exit 0 and fixes applied
  (this previously exited 1 solely because files changed);
- ``cache_stats`` gains a ``changed`` key reporting how many files were
  rewritten -- a machine-readable change channel decoupled from the exit
  code (consumed by ``jac precommit``).
- a failed write (module file or annex): exit 1, and that module is not counted as changed.
"""

import builtins;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from io { StringIO }
import from contextlib { redirect_stderr, redirect_stdout }
import from unittest.mock { patch }

import from jaclang.cli.commands.analysis { format as fmt_cmd }
import from jaclang.project { config as config_mod }

glob CLEAN = "def f(x: int) -> int {\n    return x + 1;\n}\n",
     NEEDS_FMT = "def f(x:int)->int{return x+1;}\n",
     MOD_SRC = "obj Foo { def bar -> int; }\n",
     ANNEX_SRC = "impl Foo.bar -> int {return 1;}\n";

"""Make a temp project (with jac.toml) and return its path."""
def make_project -> str {
    repo = tempfile.mkdtemp(prefix="fmt-exit-");
    (Path(repo) / "jac.toml").write_text('[project]\nname = "fx"\nversion = "0.0.1"\n');
    return repo;
}

"""Reset the config singleton; call before format()."""
def reset_state {
    config_mod._config = None;
    config_mod._config_explicit = False;
    config_mod._config_by_root = {};
}

"""Patch open() so writing any of `paths` fails like a read-only file, even as root."""
def deny_writes(paths: list[str]) -> any {
    real_open = builtins.open;
    blocked = {os.path.realpath(p) for p in paths};
    def guarded_open(file: any, mode: str = "r", *args: any, **kwargs: any) -> any {
        if "w" in mode and os.path.realpath(str(file)) in blocked {
            raise PermissionError(13, "Permission denied", str(file));
        }
        return real_open(file, mode, *args, **kwargs);
    }
    return patch("builtins.open", guarded_open);
}

test "plain fmt exits 0 after rewriting an unformatted file" {
    # The pipeline convention: `jac fmt . && jac test` must proceed after
    # files were reformatted. Exit 0 is success, even when N files changed.
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        reset_state();
        ret = fmt_cmd([str(f)]);
        rewritten = f.read_text();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert ret == 0 , f"a successful reformat must exit 0 (was: {ret}) so "
    "'jac fmt . && next' pipelines proceed";
    assert rewritten == CLEAN , f"the file must actually be rewritten, got:\n{rewritten!r}";
}

test "fmt exits 0 on an already-clean file" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(CLEAN);
        reset_state();
        ret = fmt_cmd([str(f)]);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert ret == 0 , "a no-op format is a success";
}

test "check mode exits 1 when a file would be reformatted and writes nothing" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        reset_state();
        ret = fmt_cmd([str(f)], check=True);
        on_disk = f.read_text();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert ret == 1 , "--check must exit 1 when files would change (CI gate)";
    assert on_disk == NEEDS_FMT , "--check must never modify files on disk";
}

test "to_screen exits 0, prints formatted source, leaves disk unchanged" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        reset_state();
        buf = StringIO();
        with redirect_stdout(buf) {
            ret = fmt_cmd([str(f)], to_screen=True);
        }
        out = buf.getvalue();
        on_disk = f.read_text();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert ret == 0 , "a successful preview run must exit 0 even though the "
    "file needs changes";
    assert "def f" in out , f"--to_screen must print formatted source, got {out!r}";
    assert on_disk == NEEDS_FMT , "--to_screen must leave the file unchanged";
}

test "lintfix exits 0 when every issue is auto-fixable" {
    # Regression coverage: before the fix this exited 1 solely because
    # changed_files > 0, even though lintfix fully repaired the file.
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        reset_state();
        ret = fmt_cmd([str(f)], lintfix=True);
        fixed = f.read_text();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert ret == 0 , "lintfix that repairs everything must exit 0";
    assert fixed == CLEAN , f"the auto-fixable issue must be fixed, got:\n{fixed!r}";
}

test "cache_stats reports how many files were changed" {
    # Machine-readable change channel decoupled from the exit code: callers
    # (jac precommit) must be able to ask "did fmt rewrite anything?" without
    # parsing the exit status.
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        reset_state();
        stats: dict[str, int] = {};
        fmt_cmd([str(f)], cache_stats=stats);
        changed = stats.get("changed");
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert changed == 1 , f"cache_stats['changed'] must report 1 rewritten file, "
    f"got {stats!r}";
}

test "a failed write exits 1, leaves the file alone, and is not counted as changed" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(NEEDS_FMT);
        reset_state();
        stats: dict[str, int] = {};
        with deny_writes([str(f)]) {
            ret = fmt_cmd([str(f)], cache_stats=stats, jobs="0");
        }
        on_disk = f.read_text();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert ret == 1 , f"a write failure is an operational failure and must exit 1 "
    f"(was: {ret})";
    assert on_disk == NEEDS_FMT , "the unwritable file must be left as it was";
    assert stats.get("changed") == 0 , f"an unwritten file must not count as changed, "
    f"got {stats!r}";
}

test "a directory run fails on one unwritable file and still formats the rest" {
    for jobs in ["0", "2"] {
        repo = make_project();
        old = os.getcwd();
        os.chdir(repo);
        try {
            blocked = Path(repo) / "a.jac";
            writable = Path(repo) / "b.jac";
            blocked.write_text(NEEDS_FMT);
            writable.write_text(NEEDS_FMT);
            reset_state();
            stats: dict[str, int] = {};
            out = StringIO();
            guard = deny_writes([str(blocked)]);
            with guard, redirect_stdout(out), redirect_stderr(out) {
                ret = fmt_cmd([repo], cache_stats=stats, jobs=jobs);
            }
            blocked_text = blocked.read_text();
            writable_text = writable.read_text();
        } finally {
            os.chdir(old);
            shutil.rmtree(repo, ignore_errors=True);
        }
        log = out.getvalue();
        assert ret == 1 , f"[jobs={jobs}] one failed write must fail the run "
        f"(was: {ret})\n{log}";
        assert blocked_text == NEEDS_FMT , f"[jobs={jobs}] the unwritable file must be "
        "left as it was";
        assert writable_text == CLEAN , f"[jobs={jobs}] the writable file must still be "
        "formatted";
        assert stats.get("changed") == 1 , f"[jobs={jobs}] only the written file counts "
        f"as changed, got {stats!r}";
        assert "Formatted 1/2 '.jac' files (1 changed)." in log , f"[jobs={jobs}] the "
        f"summary must not count the failed file as formatted:\n{log}";
        assert "Error writing to" in log , f"[jobs={jobs}] the write error must be "
        f"reported:\n{log}";
    }
}

test "lintfix fails when a discovered annex cannot be written" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        mod = Path(repo) / "mod.jac";
        annex = Path(repo) / "mod.impl.jac";
        mod.write_text(MOD_SRC);
        annex.write_text(ANNEX_SRC);
        reset_state();
        stats: dict[str, int] = {};
        with deny_writes([str(annex)]) {
            ret = fmt_cmd([str(mod)], lintfix=True, cache_stats=stats, jobs="0");
        }
        mod_text = mod.read_text();
        annex_text = annex.read_text();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert ret == 1 , f"an annex write failure must fail the run (was: {ret})";
    assert annex_text == ANNEX_SRC , "the unwritable annex must be left as it was";
    assert mod_text != MOD_SRC , "the module file itself is writable and still gets "
    "formatted";
    assert stats.get("changed") == 0 , f"a module whose annex failed to write must not "
    f"count as changed, got {stats!r}";
}
