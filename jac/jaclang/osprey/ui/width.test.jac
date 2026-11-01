test "ascii display_width matches string length" {
    assert display_width("") == 0;
    assert display_width("hello") == 5;
    assert display_width("a b") == 3;
}


test "ansi sequences contribute zero width" {
    colored = "\x1b[31mred\x1b[0m";
    assert display_width(colored) == 3;
    assert strip_ansi(colored) == "red";
}


test "wide cjk characters count as two columns" {
    assert display_width("你") == 2;
    assert display_width("你好") == 4;
    assert display_width("hi你") == 4;
}


test "combining marks do not add width" {
    composed = "e\u0301";
    assert display_width(composed) == 1;
}


test "emoji grapheme clusters count as two columns" {
    assert display_width("😀") == 2;
}


test "wrap_text breaks on column width not byte length" {
    lines = wrap_text("abcdefgh", 3);
    assert lines == ["abc", "def", "gh"];
}


test "wrap_text respects wide characters" {
    lines = wrap_text("你好世界", 4);
    assert lines == ["你好", "世界"];
}


test "wrap_text preserves hard newlines" {
    lines = wrap_text("ab\ncd", 10);
    assert lines == ["ab", "cd"];
}


test "truncate_text appends ellipsis within budget" {
    assert truncate_text("hello world", 8) == "hello...";
    assert truncate_text("你好世界", 5) == "你...";
}


test "truncate_text pads when requested" {
    assert truncate_text("hi", 5, pad=True) == "hi   ";
}
