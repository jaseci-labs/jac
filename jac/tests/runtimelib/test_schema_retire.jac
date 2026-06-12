"""Tests for the `__jac_schema__` retirement codemod: strip_hook_from_source / match_brace / hook_source_files."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.schema_retire {
    hook_source_files,
    match_brace,
    strip_hook_from_source
}


glob SAMPLE: str = '''node User {
    has name: str = "";
    has tags: list[str] = [];

    """Drift history for User."""
    static def __jac_schema__ -> None;

    def greet -> str {
        return "hi";
    }
}

impl User.greet -> str {
    return "hi";
}

impl User.__jac_schema__ -> None {
    schema_alias("name", stored="username");
    schema_upgrade(split, when=(lambda d: dict : isinstance(d.get("x"), str)));
}

node Other {
    static def __jac_schema__ -> None;
}

impl Other.__jac_schema__ -> None {
    schema_drop("legacy");
}
''';


test "match_brace finds the matching close, ignoring braces in strings" {
    s = 'x { a "}" { } }';
    op = s.index('{');
    close = match_brace(s, op);
    assert close == len(s) - 1 , f"expected last char, got {close}: {s[close]}";
}


test "strip removes both the decl and the impl block for the class" {
    (out, removed) = strip_hook_from_source(SAMPLE, "User");
    assert len(removed) == 2 , f"expected decl + impl removed, got {len(removed)}";
    assert "impl User.__jac_schema__" not in out;
    assert "static def __jac_schema__" in out , "Other's decl must remain";
    assert "schema_alias" not in out;
    assert "impl User.greet" in out;
    assert "def greet" in out;
    assert "has name: str" in out;
    assert "impl Other.__jac_schema__" in out;
    assert "schema_drop" in out;
}


test "the User docstring above the decl is absorbed with it" {
    (out, _removed) = strip_hook_from_source(SAMPLE, "User");
    assert "Drift history for User." not in out;
}


test "stripping is idempotent" {
    (out1, removed1) = strip_hook_from_source(SAMPLE, "User");
    assert removed1;
    (out2, removed2) = strip_hook_from_source(out1, "User");
    assert removed2 == [] , "second strip must find nothing";
    assert out2 == out1 , "second strip must not change the source";
}


test "a class with no hook yields no edits" {
    src = 'node Plain {\n    has x: int = 0;\n}\n';
    (out, removed) = strip_hook_from_source(src, "Plain");
    assert removed == [];
    assert out == src;
}


test "hook_source_files finds the file and the rewrite lands on disk" {
    with TemporaryDirectory() as tmpdir {
        pkg = os.path.join(tmpdir, "pkg");
        os.makedirs(pkg);
        os.makedirs(os.path.join(tmpdir, ".jac", "gen"));
        target = os.path.join(pkg, "models.jac");
        Path(target).write_text(SAMPLE, encoding='utf-8');
        Path(os.path.join(tmpdir, ".jac", "gen", "models.jac")).write_text(
            SAMPLE, encoding='utf-8'
        );
        found = hook_source_files(tmpdir, "User");
        assert found == [target] , f"expected only the real source, got {found}";
        src = Path(target).read_text(encoding='utf-8');
        (new_src, removed) = strip_hook_from_source(src, "User");
        assert removed , "nothing removed";
        Path(target).write_text(new_src, encoding='utf-8');
        on_disk = Path(target).read_text(encoding='utf-8');
        assert "impl User.__jac_schema__" not in on_disk;
        assert "schema_alias" not in on_disk;
        assert "impl User.greet" in on_disk , "non-hook code must survive";
        assert hook_source_files(tmpdir, "User") == [];
    }
}
