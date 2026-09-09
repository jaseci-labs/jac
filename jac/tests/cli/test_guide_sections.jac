"""Selective guide retrieval keeps context bounded without truncating sections."""

import io;
import json;
import from contextlib { redirect_stdout }
import from jaclang.cli.guide_store { Guide, guide_sections, get_guide }
import from jaclang.cli.commands.guide { guide }


test "sections respect hierarchy and ignore fenced code headings" {
    g = Guide(
        name="sample",
        description="sample",
        path="",
        body=(
            "# Guide\nintro\n## Rules\ntext\n### Detail\n"
            "```jac\n# not a heading\n```\n"
            "~~~~text\n## also not a heading\n~~~\n~~~~\n"
            "## Rules\nsecond\n## Rules-2\nthird\n"
        )
    );
    parts = guide_sections(g);
    assert [p.slug for p in parts]
        == ["guide", "rules", "detail", "rules-2", "rules-2-2"];
    assert parts[1].line_no == 3;
    assert "### Detail" in parts[1].body;
    assert "## also not a heading" in parts[1].body;
    assert "second" not in parts[1].body;
    assert parts[2].level == 3;
    assert parts[3].body == "## Rules\nsecond";
}


test "section metadata omits content and selection returns only its body" {
    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(topic="jac-types", sections=True, as_json=True);
    }
    assert rc == 0;
    payload = json.loads(buf.getvalue());
    assert payload["name"] == "jac-types";
    assert payload["sections"];
    assert all("body" not in p for p in payload["sections"]);
    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(topic="jac-types", section="pitfalls", as_json=True);
    }
    assert rc == 0;
    selected = json.loads(buf.getvalue());
    full = get_guide("jac-types");
    assert full is not None;
    expected = [
        p
        for p in guide_sections(full)
        if p.slug == "pitfalls"
    ][0];
    assert selected["body"] == expected.body;
    assert len(selected["body"]) < len(full.body);
    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(topic="jac-types", section="Pitfalls");
    }
    assert rc == 0;
    assert buf.getvalue().strip() == expected.body;
}


test "invalid selectors fail without falling back to the full guide" {
    cases = [
        {"section": "pitfalls"},
        {"topic": "jac-types", "section": "absent-section"},
        {"topic": "jac-types", "section": "pitfalls", "sections": True},
        {"topic": "jac-types", "sections": True, "search": "types"},
        {"topic": "jac-types", "sections": True, "nav": True}
    ];
    for kwargs in cases {
        buf = io.StringIO();
        with redirect_stdout(buf) {
            rc = guide(as_json=True, **kwargs);
        }
        assert rc == 1;
        assert "error" in json.loads(buf.getvalue());
    }
}


test "CLI manifest registers section flags without short-option collisions" {
    import from jaclang.cli.manifest { get_command_meta }
    meta = get_command_meta("guide");
    assert meta is not None;
    args = meta.get_all_args();
    names = {a.name for a in args};
    assert {"section", "sections"}.issubset(names);
    shorts = [
        a.short
        for a in args
        if a.short
    ];
    assert len(shorts) == len(set(shorts));
}


test "explicit heading anchors remain usable section slugs" {
    parts = guide_sections(
        Guide(
            name="sample",
            description="sample",
            path="",
            body="## Short heading {#established-link}\nContent\n"
        )
    );
    assert len(parts) == 1;
    assert parts[0].title == "Short heading";
    assert parts[0].slug == "established-link";
    assert parts[0].body.endswith("Content");
}
