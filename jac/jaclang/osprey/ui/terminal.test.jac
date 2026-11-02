test "read_terminal_size returns positive dimensions" {
    (cols, rows) = read_terminal_size();
    assert cols > 0;
    assert rows > 0;
}


test "control sequence constants are non-empty escapes" {
    assert ENTER_ALT_SCREEN.startswith("\x1b");
    assert LEAVE_ALT_SCREEN.startswith("\x1b");
    assert ENABLE_BRACKETED_PASTE.startswith("\x1b");
    assert DISABLE_BRACKETED_PASTE.startswith("\x1b");
    assert SYNC_BEGIN.startswith("\x1b");
    assert SYNC_END.startswith("\x1b");
    assert HIDE_CURSOR.startswith("\x1b");
    assert SHOW_CURSOR.startswith("\x1b");
}


test "utf8 stream decoder emits complete characters" {
    dec = Utf8StreamDecoder();
    out = dec.feed("你\n".encode());
    assert out == "你\n";
}


test "utf8 stream decoder holds split multibyte until complete" {
    enc = "你好".encode();
    dec = Utf8StreamDecoder();
    first = dec.feed(enc[0:2]);
    assert first == "";
    second = dec.feed(enc[2:4]);
    assert second == "你";
    third = dec.feed(enc[4:6]);
    assert third == "好";
}


test "utf8 stream decoder replaces invalid bytes without losing the tail" {
    dec = Utf8StreamDecoder();
    out = dec.feed(b"\xffok");
    assert "ok" in out;
}


test "utf8 stream decoder survives ascii between split multibyte" {
    enc = ("a" + "é" + "b").encode();
    dec = Utf8StreamDecoder();
    part1 = dec.feed(enc[0:2]);
    part2 = dec.feed(enc[2:]);
    assert part1 == "a";
    assert part2 == "éb";
}
