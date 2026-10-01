"""A dependency on one definition follows that definition and nothing else.

A native unit that instantiates a generic copies its body, so it must be
rebuilt when the generic changes -- but only then. Depending on the generic's
whole file (and its annexes) made every edit anywhere in `unitree` rebuild
nearly the whole compiler kernel.
"""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.jir {
    CT_DEF_FLAG,
    ct_dep_text_fresh,
    ct_deps_section,
    definition_digest
}

glob DECL = '''obj Box {
    has items: list[int] = [];

    def first -> int;
    def last -> int;
}

def helper(x: int) -> int {
    return x + 1;
}
''',
     IMPL = '''impl Box.first -> int {
    return self.items[0];
}

impl Box.last -> int {
    return self.items[-1];
}
''';

def write_module(directory: str) -> tuple[Path, Path] {
    decl = Path(directory) / "boxes.jac";
    annex = Path(directory) / "boxes.impl.jac";
    decl.write_text(DECL);
    annex.write_text(IMPL);
    return (decl, annex);
}

test "a definition's digest ignores edits to other definitions in its files" {
    with TemporaryDirectory() as directory {
        (decl, annex) = write_module(directory);
        before = definition_digest(str(decl), "Box.first");
        assert before;
        annex.write_text(IMPL.replace("self.items[-1]", "self.items[-2]"));
        decl.write_text(DECL.replace("x + 1", "x + 2"));
        assert definition_digest(str(decl), "Box.first") == before;
    }
}

test "a definition's digest follows its impl body and its declaration" {
    with TemporaryDirectory() as directory {
        (decl, annex) = write_module(directory);
        before = definition_digest(str(decl), "Box.first");
        annex.write_text(IMPL.replace("self.items[0]", "self.items[1]"));
        after_body = definition_digest(str(decl), "Box.first");
        assert after_body and after_body != before;
        decl.write_text(DECL.replace("def first -> int;", "def first -> float;"));
        assert definition_digest(str(decl), "Box.first") != after_body;
    }
}

test "a definition row stays fresh until the definition itself changes" {
    with TemporaryDirectory() as directory {
        (decl, annex) = write_module(directory);
        section = ct_deps_section([], [], definitions=[(str(decl), "Box.first")]);
        assert CT_DEF_FLAG + "Box.first" in section.decode("utf-8");
        assert ct_dep_text_fresh(section.decode("utf-8"));
        decl.write_text(DECL.replace("x + 1", "x + 3"));
        assert ct_dep_text_fresh(section.decode("utf-8"));
        annex.write_text(IMPL.replace("self.items[0]", "self.items[2]"));
        assert not ct_dep_text_fresh(section.decode("utf-8"));
    }
}

test "a definition that cannot be found is a dependency on its whole file" {
    with TemporaryDirectory() as directory {
        (decl, _) = write_module(directory);
        section = ct_deps_section([], [], definitions=[(str(decl), "Box.missing")]);
        text = section.decode("utf-8");
        assert CT_DEF_FLAG not in text;
        assert text.endswith("\tb");
        decl.write_text(DECL.replace("x + 1", "x + 4"));
        assert not ct_dep_text_fresh(section.decode("utf-8"));
    }
}

test "a top-level function is named by its bare name" {
    with TemporaryDirectory() as directory {
        (decl, _) = write_module(directory);
        before = definition_digest(str(decl), "helper");
        assert before;
        decl.write_text(DECL.replace("x + 1", "x + 5"));
        assert definition_digest(str(decl), "helper") != before;
        assert os.path.isfile(str(decl));
    }
}

test "a class or enum digest covers that declaration and nothing else" {
    with TemporaryDirectory() as directory {
        (decl, _) = write_module(directory);
        decl.write_text(DECL + "\nenum Shade {\n    LIGHT = 1,\n    DARK = 2\n}\n");
        box_before = definition_digest(str(decl), "Box");
        shade_before = definition_digest(str(decl), "Shade");
        assert box_before and shade_before;
        decl.write_text(
            DECL.replace("x + 1", "x + 6")
                + "\nenum Shade {\n    LIGHT = 1,\n    DARK = 3\n}\n"
        );
        assert definition_digest(str(decl), "Box") == box_before;
        assert definition_digest(str(decl), "Shade") != shade_before;
    }
}
