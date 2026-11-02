test "create_buffer is blank spaces" {
    buf = create_buffer(4, 2);
    assert buf.columns == 4;
    assert buf.rows == 2;
    assert buffer_get(buf, 0, 0).ch == " ";
    rows = buffer_to_plain_rows(buf);
    assert len(rows) == 2;
    assert rows[0] == "    ";
}


test "buffer_blit_text and roundtrip plain rows" {
    buf = create_buffer(8, 1);
    buffer_blit_text(buf, 0, 1, "hi", None, 4);
    assert buffer_get(buf, 0, 1).ch == "h";
    assert buffer_get(buf, 0, 2).ch == "i";
    plain = buffer_to_plain_rows(buf);
    assert "hi" in plain[0];
}


test "wide grapheme occupies two columns with wide_cont trail" {
    buf = create_buffer(6, 1);
    buffer_blit_text(buf, 0, 0, "你a", None, 6);
    lead = buffer_get(buf, 0, 0);
    trail = buffer_get(buf, 0, 1);
    ascii_c = buffer_get(buf, 0, 2);
    assert lead.ch == "你";
    assert not lead.wide_cont;
    assert trail.wide_cont;
    assert ascii_c.ch == "a";
    assert not ascii_c.wide_cont;
    plain = buffer_to_plain_rows(buf);
    assert plain[0].startswith("你a");
}


test "wide grapheme clips when only one column remains" {
    buf = create_buffer(3, 1);
    buffer_blit_text(buf, 0, 0, "xy你", None, 3);
    assert buffer_get(buf, 0, 0).ch == "x";
    assert buffer_get(buf, 0, 1).ch == "y";

    assert buffer_get(buf, 0, 2).ch == " ";
    assert not buffer_get(buf, 0, 2).wide_cont;
}


test "buffer_blit_spans advances by display width" {
    buf = create_buffer(8, 1);
    spans = [
        TextSpan(text="你", attrs=StyleAttrs(bold=True)),
        TextSpan(text="ok", attrs=StyleAttrs()),

    ];
    buffer_blit_spans(buf, 0, 0, spans, 8);
    assert buffer_get(buf, 0, 0).ch == "你";
    assert buffer_get(buf, 0, 0).attrs.bold;
    assert buffer_get(buf, 0, 1).wide_cont;
    assert buffer_get(buf, 0, 2).ch == "o";
    assert buffer_get(buf, 0, 3).ch == "k";
}


test "attrs_eq and cell_eq detect style-only change" {
    a = StyleAttrs(bold=True, fg=1);
    b = StyleAttrs(bold=True, fg=1);
    c = StyleAttrs(bold=False, fg=1);
    assert attrs_eq(a, b);
    assert not attrs_eq(a, c);
    ca = StyledCell(ch="x", attrs=a);
    cb = StyledCell(ch="x", attrs=b);
    cc = StyledCell(ch="x", attrs=c);
    assert cell_eq(ca, cb);
    assert not cell_eq(ca, cc);
}


test "sgr_for emits bold and color" {
    s = sgr_for(StyleAttrs(bold=True, fg=1));
    assert "\x1b[" in s;
    assert "1" in s;
    assert "31" in s or "38" in s;
    assert sgr_reset() == "\x1b[0m";
}


test "style-only change produces SGR in diff" {
    prev = create_buffer(4, 1);
    buffer_blit_text(prev, 0, 0, "ab", None, 4);
    desired = create_buffer(4, 1);
    buffer_blit_text(desired, 0, 0, "ab", StyleAttrs(bold=True), 4);
    diff = diff_buffers_ansi(prev, desired, []);
    assert diff.cells_written >= 2;
    assert "\x1b[" in diff.text;
    assert "1m" in diff.text or ";1" in diff.text or "[1;" in diff.text;
}


test "wide cell diff skips wide_cont columns" {
    prev = create_buffer(4, 1);
    desired = create_buffer(4, 1);
    buffer_blit_text(desired, 0, 0, "你", None, 4);
    diff = diff_buffers_ansi(prev, desired, []);
    assert "你" in diff.text;
    assert diff.cells_written == 1;
}


test "unchanged region writes zero cells" {
    prev = create_buffer(4, 2);
    buffer_blit_text(prev, 0, 0, "ab", None, 4);
    desired = create_buffer(4, 2);
    buffer_blit_text(desired, 0, 0, "ab", None, 4);
    diff = diff_buffers_ansi(prev, desired, [Rect(x=0, y=0, width=4, height=2)]);
    assert diff.cells_written == 0;
    assert diff.text == "" or diff.text == sgr_reset();
}


test "buffer_from_plain_rows fills grid" {
    buf = buffer_from_plain_rows(["xy", "z"], 3, 2);
    assert buffer_get(buf, 0, 0).ch == "x";
    assert buffer_get(buf, 0, 1).ch == "y";
    assert buffer_get(buf, 1, 0).ch == "z";
}
