"""Idempotency contract tests for ``jac fmt`` (issue #8564).

``jac fmt`` used to prepend one blank line per pass on comment-only files:
the comment attached as a trailing-own-line comment of the module's synthetic
``EmptyToken`` (degenerate loc (0,0)), whose emitter always inserts a hard
line after the (empty) base and then misread the blank line it had itself
inserted as source-intentional spacing on the next parse. Files grew
``# c`` -> ``\\n# c`` -> ``\\n\\n# c`` and only then converged.

The observable contract pinned here:

- comment-only files format to themselves and are byte-stable across passes;
- leading blank lines are normalized away (same as files with statements);
- blank lines *between* comments are preserved;
- files with statements (leading comments, own-line comments, comments in
  empty blocks) remain byte-identical across passes.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }

import from jaclang.cli.commands.analysis { format as fmt_cmd }
import from jaclang.project { config as config_mod }

glob COMMENT_ONLY = "# c\n",
     TWO_COMMENTS = "# a\n# b\n",
     COMMENT_NO_EOL = "# c",
     LEADING_BLANKS = "\n\n# c\n",
     GAP_BETWEEN = "# a\n\n# b\n",
     STMT_WITH_LEADING_COMMENT = "# c\ndef f(x: int) -> int {\n    return x + 1;\n}\n",
     EMPTY_BLOCK_COMMENT = "def f() -> int {\n    # todo\n}\n";

"""Make a temp project (with jac.toml) and return its path."""
def make_project -> str {
    repo = tempfile.mkdtemp(prefix="fmt-idem-");
    (Path(repo) / "jac.toml").write_text('[project]\nname = "fi"\nversion = "0.0.1"\n');
    return repo;
}

"""Reset the config singleton; call before format()."""
def reset_state {
    config_mod._config = None;
    config_mod._config_explicit = False;
    config_mod._config_by_root = {};
}

"""Format `path` twice, returning the bytes after each pass."""
def fmt_twice(path: Path) -> tuple[str, str] {
    reset_state();
    assert fmt_cmd([str(path)]) == 0 , "first format pass must succeed";
    after_first = path.read_text();
    reset_state();
    assert fmt_cmd([str(path)]) == 0 , "second format pass must succeed";
    after_second = path.read_text();
    return (after_first, after_second);
}

test "comment-only file formats to itself, byte-stable across passes" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "c.jac";
        f.write_text(COMMENT_ONLY);
        (after_first, after_second) = fmt_twice(f);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert after_first == COMMENT_ONLY , f"first pass must leave '# c\\n' alone, got: {after_first!r}";
    assert after_second == COMMENT_ONLY , f"second pass must be byte-identical, got: {after_second!r}";
}

test "multiple comment-only lines are idempotent" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "c.jac";
        f.write_text(TWO_COMMENTS);
        (after_first, after_second) = fmt_twice(f);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert after_first == TWO_COMMENTS , f"first pass must not grow the file, got: {after_first!r}";
    assert after_second == TWO_COMMENTS , f"second pass must be byte-identical, got: {after_second!r}";
}

test "comment without trailing newline gains exactly the final newline" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "c.jac";
        f.write_text(COMMENT_NO_EOL);
        (after_first, after_second) = fmt_twice(f);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert after_first == COMMENT_ONLY , f"expected '# c\\n', got: {after_first!r}";
    assert after_second == COMMENT_ONLY , f"second pass must be byte-identical, got: {after_second!r}";
}

test "leading blank lines on comment-only files are normalized, not grown" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "c.jac";
        f.write_text(LEADING_BLANKS);
        (after_first, after_second) = fmt_twice(f);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    # Mirrors files with statements: jac fmt already strips leading blanks there.
    assert after_first == COMMENT_ONLY , f"expected leading blanks stripped, got: {after_first!r}";
    assert after_second == COMMENT_ONLY , f"second pass must be byte-identical, got: {after_second!r}";
}

test "blank line between comments is preserved, idempotently" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "c.jac";
        f.write_text(GAP_BETWEEN);
        (after_first, after_second) = fmt_twice(f);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert after_first == GAP_BETWEEN , f"inter-comment blank line must survive, got: {after_first!r}";
    assert after_second == GAP_BETWEEN , f"second pass must be byte-identical, got: {after_second!r}";
}

test "statement files with comments stay byte-identical across passes" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(STMT_WITH_LEADING_COMMENT);
        (after_first, after_second) = fmt_twice(f);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert after_first == STMT_WITH_LEADING_COMMENT , f"got: {after_first!r}";
    assert after_second == STMT_WITH_LEADING_COMMENT , f"got: {after_second!r}";
}

test "own-line comment inside an empty block stays byte-identical" {
    repo = make_project();
    old = os.getcwd();
    os.chdir(repo);
    try {
        f = Path(repo) / "a.jac";
        f.write_text(EMPTY_BLOCK_COMMENT);
        (after_first, after_second) = fmt_twice(f);
    } finally {
        os.chdir(old);
        shutil.rmtree(repo, ignore_errors=True);
    }
    assert after_first == EMPTY_BLOCK_COMMENT , f"got: {after_first!r}";
    assert after_second == EMPTY_BLOCK_COMMENT , f"got: {after_second!r}";
}
