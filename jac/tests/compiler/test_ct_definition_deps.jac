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

# A prepared-application restore re-verifies every input's content+annex digest
# before loading sections, so row checks against those files would only
# re-derive equal digests. `validated` names that caller-checked set: rows for
# its files are trusted, anything else is still re-digested.
test "validated inputs skip re-checking rows for files already digested" {
    with TemporaryDirectory() as directory {
        (decl, annex) = write_module(directory);
        section = ct_deps_section([], [], definitions=[(str(decl), "Box.first")]);
        validated = {os.path.realpath(str(decl))};
        annex.write_text(IMPL.replace("self.items[0]", "self.items[2]"));
        assert ct_dep_text_fresh(section.decode("utf-8"), validated=validated);
    }
}

test "rows outside the validated set are still checked" {
    with TemporaryDirectory() as directory {
        (decl, annex) = write_module(directory);
        stray = Path(directory) / "stray.jac";
        stray.write_text("def stray -> int { return 1; }\n");
        section = ct_deps_section(
            [str(stray)], [], definitions=[(str(decl), "Box.first")]
        );
        validated = {os.path.realpath(str(decl))};
        assert ct_dep_text_fresh(section.decode("utf-8"), validated=validated);
        stray.write_text("def stray -> int { return 2; }\n");
        assert not ct_dep_text_fresh(section.decode("utf-8"), validated=validated);
    }
}

"""Whoever compiled a module already knows where its definitions sit. The
positions read off an analysed tree, annexes included, give the same digests
as parsing the files again, so the session that holds the tree can hand them
over and the files are not parsed a second time to key a dependency."""
test "definition positions from an analysed tree give the parsed digests" {
    import from unittest.mock { patch }
    import jaclang.compiler.driver.jir as jir_mod;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.unit_products { definition_span_rows }
    with TemporaryDirectory() as directory {
        (decl, annex) = write_module(os.path.realpath(directory));
        names = ("Box.first", "Box.last", "Box", "helper");
        parsed = {name: definition_digest(str(decl), name) for name in names};
        assert all(parsed.values()) , parsed;
        analysed = JacProgram().compile(str(decl));
        rows = definition_span_rows(analysed);
        assert any(str(annex) in row for row in rows) , rows;
        jir_mod._DEFINITION_TEXTS.clear();
        jir_mod.seed_definition_texts(rows);
        def refuse(*args: any, **kwargs: any) -> any {
            raise AssertionError("the files were parsed again");
        }
        with patch.object(JacProgram, "parse_source", refuse) {
            seeded = {name: definition_digest(str(decl), name) for name in names};
        }
        assert seeded == parsed;
    }
}
