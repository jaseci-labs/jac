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

import from jaclang.cli.commands.analysis { format as fmt_cmd, lint as lint_cmd }
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

test "lintfix moves separate-impls bodies into the module's impl annex" {
    for jobs in ("0", "2") {
        repo = make_project();
        (Path(repo) / "jac.toml").write_text(
            '[project]\nname = "fx"\nversion = "0.0.1"\n\n'
                + '[check.lint]\nselect = ["separate-impls"]\n'
        );
        old = os.getcwd();
        os.chdir(repo);
        try {
            fresh = Path(repo) / "fresh.jac";
            fresh.write_text(CLEAN);
            mod = Path(repo) / "mod.jac";
            annex = Path(repo) / "mod.impl.jac";
            mod.write_text(
                MOD_SRC + "\ndef g(x: int) -> int {\n    return x * 2;\n}\n"
            );
            annex.write_text(ANNEX_SRC);
            variant = Path(repo) / "fresh.native.jac";
            variant.write_text(CLEAN);
            blocked = Path(repo) / "blocked.jac";
            blocked.write_text(CLEAN);
            stuck = Path(repo) / "stuck.jac";
            stuck.write_text(CLEAN);
            wide = Path(repo) / "wide.jac";
            wide.write_text(
                MOD_SRC + "\ndef h(x: int) -> int {\n    return x - 1;\n}\n"
            );
            (Path(repo) / "wide.impl.jac").write_bytes(ANNEX_SRC.encode("utf-16"));
            files = [
                "fresh.jac",
                str(mod),
                str(annex),
                str(variant),
                str(blocked),
                str(stuck),
                str(wide)
            ];
            reset_state();
            with deny_writes(
                [str(Path(repo) / "impl" / "blocked.impl.jac"), str(stuck)]
            ) {
                ret = fmt_cmd(files, lintfix=True, jobs=jobs);
            }
            stuck_annex_left = (Path(repo) / "impl" / "stuck.impl.jac").exists();
            wide_annex = (Path(repo) / "wide.impl.jac").read_bytes();
            fresh_text = fresh.read_text();
            fresh_annex = (Path(repo) / "impl" / "fresh.impl.jac").read_text();
            mod_text = mod.read_text();
            annex_text = annex.read_text();
            variant_annex = (
                Path(repo) / "fresh.native.impl" / "fresh.native.impl.jac"
            ).read_text();
            blocked_text = blocked.read_text();
            files.remove(str(blocked));
            files.remove(str(stuck));
            reset_state();
            again = fmt_cmd(files, lintfix=True, check=True, jobs=jobs);
        } finally {
            os.chdir(old);
            shutil.rmtree(repo, ignore_errors=True);
        }
        assert ret == 1 , f"[jobs={jobs}] the unwritable annex must fail the run";
        assert blocked_text == CLEAN , f"[jobs={jobs}] a module whose annex cannot be "
        f"written keeps its bodies, got:\n{blocked_text!r}";
        assert b"impl h(" in wide_annex and b"bar" in wide_annex , (
            f"[jobs={jobs}] a UTF-16 annex is fixed like any other, got {wide_annex!r}"
        );
        assert not stuck_annex_left , f"[jobs={jobs}] an annex written for a module "
        "that then fails to save is rolled back";
        assert "return x + 1" in variant_annex , (
            f"[jobs={jobs}] a platform variant gets its own annex folder, so the "
            "portable module does not claim its bodies"
        );
        assert fresh_text == "def f(x: int) -> int;\n" , f"[jobs={jobs}] the module "
        f"keeps only the declaration, got:\n{fresh_text!r}";
        assert fresh_annex == "impl f(x: int) -> int {\n    return x + 1;\n}\n" , (
            f"[jobs={jobs}] a module with no annex gets one in impl/, got:\n{fresh_annex!r}"
        );
        assert "def g(x: int) -> int;" in mod_text and "return x * 2" not in mod_text , (
            f"[jobs={jobs}] the body leaves the module, got:\n{mod_text!r}"
        );
        assert annex_text.index("impl Foo.bar") < annex_text.index("impl g(") , (
            f"[jobs={jobs}] an existing annex keeps its impls and gains the moved "
            f"one, got:\n{annex_text!r}"
        );
        assert again == 0 , f"[jobs={jobs}] a second run must find nothing to move";
    }
}

test "lintfix moves impls-in-annex impls and sibling annexes into an impl folder" {
    for mode in ("fmt-0", "fmt-2", "lint") {
        repo = make_project();
        (Path(repo) / "jac.toml").write_text(
            '[project]\nname = "fx"\nversion = "0.0.1"\n\n'
                + '[check.lint]\nselect = ["impls-in-annex"]\n'
        );
        old = os.getcwd();
        os.chdir(repo);
        try {
            decl = "obj Foo {\n    def bar -> int;\n}\n";
            proj = Path(repo);
            (proj / "inline.jac").write_text(decl + "\n" + ANNEX_SRC);
            (proj / "side.jac").write_text(decl);
            (proj / "side.impl.jac").write_text(ANNEX_SRC);
            (proj / "both.jac").write_text(
                "obj Foo {\n    def bar -> int;\n    def baz -> int;\n}\n\n"
                    + "impl Foo.baz -> int {\n    return 2;\n}\n"
            );
            (proj / "both.impl.jac").write_text(ANNEX_SRC);
            (proj / "plat.native.jac").write_text(decl);
            (proj / "plat.native.impl.jac").write_text(ANNEX_SRC);
            (proj / "settled.jac").write_text(decl);
            (proj / "impl").mkdir();
            settled_src = "impl Foo.bar -> int {\n    return 1;\n}\n";
            (proj / "impl" / "settled.impl.jac").write_text(settled_src);
            inputs = [str(p) for p in sorted(proj.glob("*.jac"))];
            reset_state();
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()) {
                if mode == "lint" {
                    ret = lint_cmd(inputs, fix=True);
                } else {
                    ret = fmt_cmd(inputs, lintfix=True, jobs=mode[-1]);
                }
            }
            left = sorted(p.name for p in proj.glob("*.impl.jac"));
            inline_text = (proj / "inline.jac").read_text();
            inline_annex = (proj / "impl" / "inline.impl.jac").read_text();
            side_annex = (proj / "impl" / "side.impl.jac").read_text();
            both_text = (proj / "both.jac").read_text();
            both_annex = (proj / "impl" / "both.impl.jac").read_text();
            plat_annex = (
                proj / "plat.native.impl" / "plat.native.impl.jac"
            ).read_text();
            settled_annex = (proj / "impl" / "settled.impl.jac").read_text();
            reset_state();
            inputs = [str(p) for p in sorted(proj.glob("**/*.jac"))];
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()) {
                again = fmt_cmd(inputs, lintfix=True, check=True);
            }
        } finally {
            os.chdir(old);
            shutil.rmtree(repo, ignore_errors=True);
        }
        assert ret == 0 , f"[{mode}] every move is fixable, got {ret}";
        assert left == [] , f"[{mode}] no annex stays beside its module, got {left}";
        assert "impl" not in inline_text and "return 1" in inline_annex , (
            f"[{mode}] an impl in the module moves to impl/, got:\n{inline_text!r}"
        );
        assert "return 1" in side_annex , f"[{mode}] a sibling annex moves to impl/";
        assert "impl" not in both_text , f"[{mode}] got:\n{both_text!r}";
        assert "Foo.bar" in both_annex and "Foo.baz" in both_annex , (
            f"[{mode}] the moved impl joins the relocated annex, got:\n{both_annex!r}"
        );
        assert "return 1" in plat_annex , f"[{mode}] a dotted stem keeps its folder";
        assert settled_annex == settled_src , f"[{mode}] a placed annex is untouched";
        assert again == 0 , f"[{mode}] a second run must find nothing to move";
    }
}

"""Run lintfix over `inputs` in `mode`: fmt-0, fmt-2 (pooled) or lint."""
def run_lintfix(mode: str, inputs: list[str]) -> int {
    reset_state();
    with redirect_stdout(StringIO()), redirect_stderr(StringIO()) {
        if mode == "lint" {
            return lint_cmd(inputs, fix=True);
        }
        return fmt_cmd(inputs, lintfix=True, jobs=mode[-1]);
    }
}

"""Make a project that selects impls-in-annex and chdir into it."""
def annex_project -> str {
    repo = make_project();
    (Path(repo) / "jac.toml").write_text(
        '[project]\nname = "fx"\nversion = "0.0.1"\n\n'
            + '[check.lint]\nselect = ["impls-in-annex"]\n'
    );
    return repo;
}

glob DECL = "obj Foo {\n    def bar -> int;\n}\n",
     IMPL = "impl Foo.bar -> int {\n    return 1;\n}\n";

test "lintfix gives a variant's sibling annex one home, beside the variant" {
    for mode in ("fmt-0", "fmt-2", "lint") {
        repo = annex_project();
        old = os.getcwd();
        os.chdir(repo);
        try {
            proj = Path(repo);
            (proj / "foo.jac").write_text(DECL);
            (proj / "foo.native.jac").write_text(DECL);
            (proj / "foo.native.impl.jac").write_text(IMPL);
            ret = run_lintfix(
                mode, [str(proj / "foo.jac"), str(proj / "foo.native.jac")]
            );
            homes = sorted(str(p.relative_to(proj)) for p in proj.rglob("*.impl.jac"));
        } finally {
            os.chdir(old);
            shutil.rmtree(repo, ignore_errors=True);
        }
        assert ret == 0 , f"[{mode}] got {ret}";
        assert homes == ["foo.native.impl/foo.native.impl.jac"] , f"[{mode}] {homes}";
    }
}

test "lintfix on a sibling annex alone moves it through its module" {
    for mode in ("fmt-0", "lint") {
        repo = annex_project();
        old = os.getcwd();
        os.chdir(repo);
        try {
            proj = Path(repo);
            (proj / "side.jac").write_text(DECL);
            (proj / "side.impl.jac").write_text(IMPL);
            ret = run_lintfix(mode, [str(proj / "side.impl.jac")]);
            moved = (proj / "impl" / "side.impl.jac").exists();
            left = (proj / "side.impl.jac").exists();
        } finally {
            os.chdir(old);
            shutil.rmtree(repo, ignore_errors=True);
        }
        assert ret == 0 and moved and not left , f"[{mode}] ret={ret} moved={moved} left={left}";
    }
}

test "lint --fix leaves an ignored module alone even when its sibling annex is selected" {
    repo = annex_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        proj = Path(repo);
        (proj / "side.jac").write_text(DECL + "\n" + IMPL);
        mod_src = (proj / "side.jac").read_text();
        (proj / "side.impl.jac").write_text(
            "impl Foo.baz -> int {\n    return 2;\n}\n"
        );
        reset_state();
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()) {
            lint_cmd([repo], fix=True, ignore=["side.jac"]);
        }
        mod_text = (proj / "side.jac").read_text();
        moved = (proj / "impl" / "side.impl.jac").exists();
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert mod_text == mod_src , f"the ignored module is untouched, got:\n{mod_text!r}";
    assert not moved , "its annex is only moved through the module, which is ignored";
}

test "lintfix rolls a move back when the old annex cannot be removed" {
    for mode in ("fmt-0", "fmt-2", "lint") {
        repo = annex_project();
        old = os.getcwd();
        os.chdir(repo);
        try {
            proj = Path(repo);
            (proj / "side.jac").write_text(
                "obj Foo {\n    def bar -> int;\n    def baz -> int;\n}\n\n"
                    + "impl Foo.baz -> int {\n    return 2;\n}\n"
            );
            mod_src = (proj / "side.jac").read_text();
            (proj / "side.impl.jac").write_text(IMPL);
            sibling = os.path.realpath(proj / "side.impl.jac");
            real_unlink = Path.unlink;
            def guarded_unlink(self: Path, missing_ok: bool = False) {
                if os.path.realpath(self) == sibling {
                    raise PermissionError(13, "Permission denied", str(self));
                }
                real_unlink(self, missing_ok=missing_ok);
            }
            with patch.object(Path, "unlink", guarded_unlink) {
                ret = run_lintfix(mode, [str(proj / "side.jac")]);
            }
            mod_text = (proj / "side.jac").read_text();
            copies = sorted(str(p.relative_to(proj)) for p in proj.rglob("*.impl.jac"));
        } finally {
            os.chdir(old);
            shutil.rmtree(repo, ignore_errors=True);
        }
        assert ret == 1 , f"[{mode}] a failed removal fails the run, got {ret}";
        assert copies == ["side.impl.jac"] , f"[{mode}] no second copy survives: {copies}";
        assert mod_text == mod_src , f"[{mode}] the module is restored, got:\n{mod_text!r}";
    }
}

test "lintfix keeps a module's bodies when its impl annex cannot be formatted" {
    broken = "impl Foo.bar -> int {\n    return 1;\n";
    for mode in ("fmt-0", "fmt-2", "lint") {
        repo = make_project();
        (Path(repo) / "jac.toml").write_text(
            '[project]\nname = "fx"\nversion = "0.0.1"\n\n'
                + '[check.lint]\nselect = ["separate-impls"]\n'
        );
        old = os.getcwd();
        os.chdir(repo);
        try {
            mod = Path(repo) / "mod.jac";
            annex = Path(repo) / "mod.impl.jac";
            mod_src = MOD_SRC + "\n" + CLEAN;
            mod.write_text(mod_src);
            annex.write_text(broken);
            other = Path(repo) / "other.jac";
            other_src = "glob LIMIT: int = 3;\n";
            other.write_text(other_src);
            inputs = [str(mod), str(other)];
            reset_state();
            stats: dict[str, int] = {};
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()) {
                if mode == "lint" {
                    ret = lint_cmd(inputs, fix=True);
                } else {
                    ret = fmt_cmd(
                        inputs, lintfix=True, jobs=mode[-1], cache_stats=stats
                    );
                }
            }
            mod_text = mod.read_text();
            annex_text = annex.read_text();
            other_text = other.read_text();
        } finally {
            os.chdir(old);
            shutil.rmtree(repo, ignore_errors=True);
        }
        assert ret == 1 , f"[{mode}] an annex that cannot be formatted fails the run";
        assert mod_text == mod_src , f"[{mode}] the module keeps its bodies, got:\n"
        f"{mod_text!r}";
        assert annex_text == broken , f"[{mode}] the broken annex is left as it was, "
        f"got:\n{annex_text!r}";
        assert stats.get("changed", 0) == 0 , f"[{mode}] a module left unchanged is "
        f"not counted as changed, got {stats!r}";
        assert other_text == other_src , f"[{mode}] the clean module beside it is "
        f"untouched, got:\n{other_text!r}";
    }
}
