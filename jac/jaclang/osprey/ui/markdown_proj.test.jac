test "project_inline_spans marks strong em code strike" {
    spans = project_inline_spans("a **b** c *d* `e` ~~f~~");
    ids = [s.style_id for s in spans];
    texts = [s.text for s in spans];
    assert "strong" in ids;
    assert "em" in ids;
    assert "codespan" in ids;
    assert "strike" in ids;
    assert "b" in texts;
    assert "d" in texts;
    assert "e" in texts;
    assert "f" in texts;
}


test "project_markdown headings fences lists hr" {
    src = "# Title\n\n- item **one**\n\n```\ncode\n```\n\n---\n";
    lines = project_markdown(src, width=40);
    assert len(lines) >= 4;
    styles = [];
    for line in lines {
        if line.spans {
            styles.append(line.spans[0].style_id);
        }
    }
    assert "heading" in styles;
    assert "list_marker" in styles
        or any(s.style_id == "strong" for line in lines for s in line.spans);
    assert "code" in styles;
    assert "hr" in styles;
}


test "looks_like_markdown detects common markers" {
    assert looks_like_markdown("# hi");
    assert looks_like_markdown("use **bold**");
    assert looks_like_markdown("- a\n- b");
    assert not looks_like_markdown("plain text only");
}


test "proj_lines_to_span_dicts preserves text" {
    lines = project_markdown("hello **world**", 40);
    dicts = proj_lines_to_span_dicts(lines);
    assert len(dicts) >= 1;
    text = str(dicts[0]["text"]);
    assert "hello" in text;
    assert "world" in text;
}


test "style_attrs_for maps known ids" {
    assert style_attrs_for("heading").bold;
    assert style_attrs_for("em").italic;
    assert style_attrs_for("code").fg == 3;
}
