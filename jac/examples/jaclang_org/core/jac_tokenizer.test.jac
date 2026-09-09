def kinds(line: str) -> list[str] {
    return [t.kind for t in scan_line(line).tokens];
}

def texts(line: str) -> list[str] {
    return [t.text for t in scan_line(line).tokens];
}

test "keywords types and literals are classified" {
    assert classify("walker", " ") == "kw";
    assert classify("node", " ") == "kw";
    assert classify("int", " ") == "ty";
    assert classify("True", " ") == "lit";
    assert classify("root", " ") == "var";
    assert classify("MyThing", " ") == "ty";
    assert classify("do_work", "(") == "fn";
    assert classify("whatever", " ") == "plain";
}

test "a declaration tokenizes end to end" {
    scan = scan_line("walker:pub add_task {");
    assert scan.mode == "";
    assert scan.tokens[0].text == "walker";
    assert scan.tokens[0].kind == "kw";
    assert "pub" in texts("walker:pub add_task {");
    assert "fn" in kinds("report add_task(title=t);");
}

test "line comments run to end of line" {
    ks = kinds("has x: int = 1;  # trailing note");
    assert ks[-1] == "com";
    assert texts("has x: int = 1;  # trailing note")[-1] == "# trailing note";
}

test "strings are one token" {
    assert texts('print("hello world");')[2] == '"hello world"';
    assert kinds('print("hello world");')[2] == "str";
}

test "unterminated triple quote carries mode to next line" {
    first = scan_line('x = """start');
    assert first.mode == "d3";
    second = scan_line("still inside", first.mode);
    assert second.mode == "d3";
    third = scan_line('done """;', second.mode);
    assert third.mode == "";
}

test "block comments carry mode across lines" {
    first = scan_line("#* opening");
    assert first.mode == "mc";
    assert first.tokens[0].kind == "com";
    second = scan_line("closing *#", first.mode);
    assert second.mode == "";
}

test "numbers and hex stay together" {
    assert "num" in kinds("x = 0x1700;");
    assert "num" in kinds("y = 3.14159;");
}

test "connect operators are operators" {
    assert "op" in kinds("root ++> Task();");
    assert "op" in kinds("hub +>:Contains():+> page;");
}

test "decorators are their own kind" {
    assert kinds("@staticmethod")[0] == "dec";
}

test "non highlighted languages pass through verbatim" {
    rows = tokenize_lines(["some plain text", "more"], "markdown");
    assert len(rows) == 2;
    assert len(rows[0]) == 1;
    assert rows[0][0].text == "some plain text";
    assert rows[0][0].kind == "plain";
}

test "tokenize lines threads mode between lines" {
    rows = tokenize_lines(['s = """open', "middle", 'close """;'], "jac");
    assert len(rows) == 3;
    assert rows[1][0].kind == "str";
}

test "round trip preserves every character" {
    src = 'def f(x: int) -> str { return "a" + str(x); }  # note';
    joined = "".join(texts(src));
    assert joined == src;
}
