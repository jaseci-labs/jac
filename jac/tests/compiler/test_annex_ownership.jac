"""Every annex has one owner: the module with the longest dotted stem that
exists beside it. Discovery from a module and the base lookup from an annex
agree on that owner, so a platform variant's annex never also lands in the
portable module."""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.bccache { discover_annex_files, discover_base_file }

def _names(paths: list[str], top: str) -> list[str] {
    return sorted(os.path.relpath(p, top) for p in paths);
}

test "a variant's annex belongs to the variant, a split annex to the module" {
    with tempfile.TemporaryDirectory() as directory {
        top = os.path.realpath(directory);
        d = Path(top);
        (d / "impl").mkdir();
        for name in [
            "foo.jac",
            "foo.native.jac",
            "foo.part.impl.jac",
            "foo.native.impl.jac",
            "impl/foo.native.impl.jac",
            "impl/foo.impl.jac"
        ] {
            (d / name).write_text("");
        }
        assert _names(discover_annex_files(str(d / "foo.jac")), top)
            == ["foo.part.impl.jac", "impl/foo.impl.jac"];
        assert _names(discover_annex_files(str(d / "foo.native.jac")), top)
            == ["foo.native.impl.jac", "impl/foo.native.impl.jac"];
        for (annex, owner) in [
            ("foo.part.impl.jac", "foo.jac"),
            ("foo.native.impl.jac", "foo.native.jac"),
            ("impl/foo.native.impl.jac", "foo.native.jac"),
            ("impl/foo.impl.jac", "foo.jac")
        ] {
            assert discover_base_file(str(d / annex)) == str(d / owner) , annex;
        }
    }
}

test "a variant with no portable module still owns its sibling annex" {
    with tempfile.TemporaryDirectory() as directory {
        d = Path(os.path.realpath(directory));
        (d / "plat.native.jac").write_text("");
        (d / "plat.native.impl.jac").write_text("");
        assert discover_base_file(str(d / "plat.native.impl.jac"))
            == str(d / "plat.native.jac");
    }
}
