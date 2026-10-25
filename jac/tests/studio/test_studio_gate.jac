"""Compiler-checked edits: accepting part of an edit symbol by symbol."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.studio.gate {
    EditGate,
    change_groups,
    partial_text,
    symbol_changes
}

glob OLD: str = "obj P {\n    has a: int = 1, b: int = 2;\n\n    def f -> int {\n        return 1;\n    }\n}\n",
     NEW: str = "obj P {\n    has a: int = 5, b: int = 7;\n\n    def f -> int {\n        return 2;\n    }\n}\n";

test "changes that share a line are kept or dropped together" {
    with TemporaryDirectory() as tmp {
        path = str(Path(tmp) / "p.jac");
        Path(path).write_text(OLD);
        changes = symbol_changes(OLD, NEW, path);
        groups = change_groups(changes);
        assert sorted(groups["P.a"]) == ["P.a", "P.b"] , groups;
        assert groups["P.f"] == ["P.f"];
        keep_b = partial_text(OLD, NEW, changes, {"P.b"});
        assert "has a: int = 5, b: int = 7;" in keep_b , keep_b;
        assert "return 1;" in keep_b;
        keep_f = partial_text(OLD, NEW, changes, {"P.f"});
        assert "has a: int = 1, b: int = 2;" in keep_f , keep_f;
        assert "return 2;" in keep_f;
    }
}

test "a review cancelled before it runs stages nothing" {
    with TemporaryDirectory() as tmp {
        path = str(Path(tmp) / "p.jac");
        Path(path).write_text(OLD);
        gate = EditGate(root_dir=tmp);
        def always -> bool {
            return True;
        }
        rv = gate.review(path, NEW, always);
        assert rv.check_error.startswith("cancelled") , rv.check_error;
        assert not gate.staged() , "a cancelled review must not leave the rejected text staged";
        gate.stage(path, NEW);
        gate.unstage_if(path, "something else");
        assert gate.staged() , "unstage_if keeps text it did not stage";
        gate.unstage_if(path, NEW);
        assert not gate.staged();
    }
}

test "a cached baseline is redone when a file the check read changes" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / "jac.toml").write_text("[project]\nname = \"g\"\n");
        (base / "a.jac").write_text("def other -> int {\n    return 1;\n}\n");
        target = base / "b.jac";
        target.write_text(
            "import from a { thing }\n\nwith entry {\n    print(thing());\n}\n"
        );
        gate = EditGate(root_dir=tmp);
        before = gate._baseline(str(target));
        assert any([d.code == "W1101" for d in before]) , [d.message for d in before];
        (base / "a.jac").write_text(
            "def other -> int {\n    return 1;\n}\n\ndef thing -> int {\n    return 2;\n}\n"
        );
        after = gate._baseline(str(target));
        assert not any([d.code == "W1101" for d in after]) , "the baseline kept a finding the change to a.jac fixed";
    }
}
