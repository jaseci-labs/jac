"""`jac browse press` accepts combos such as Control+Shift+f and turns the
modifier names into CDP modifier flags (Alt 1, Control 2, Meta 4, Shift 8).
Before this the whole string went to Input.dispatchKeyEvent as the key with no
modifiers, so a page's Ctrl and Cmd shortcuts could not be driven headlessly."""

import from jaclang.cli.browser_engine {
    _parse_key_combo,
    _key_down,
    _select_all_modifier
}

test "modifier names become cdp flags" {
    assert _parse_key_combo("Control+b") == ("b", 2);
    assert _parse_key_combo("Ctrl+Shift+f") == ("f", 10);
    assert _parse_key_combo("Meta+Enter") == ("Enter", 4);
    assert _parse_key_combo("Alt+Shift+ArrowDown") == ("ArrowDown", 9);
}

test "plain keys and a literal plus pass through" {
    assert _parse_key_combo("Enter") == ("Enter", 0);
    assert _parse_key_combo("+") == ("+", 0);
    assert _parse_key_combo("Control++") == ("+", 2);
    assert _parse_key_combo("nope+x") == ("nope+x", 0);
}

test "Enter carries a carriage return so it submits forms and breaks lines" {
    down = _key_down("Enter");
    assert down["text"] == "\r" and down["windowsVirtualKeyCode"] == 13;
    assert down["code"] == "Enter";
    assert _key_down("Enter", 8)["text"] == "\r";
    assert "text" not in _key_down("Enter", 2);
    assert "text" not in _key_down("Tab");
    assert _key_down("a")["text"] == "a" and _key_down("a")["code"] == "KeyA";
    assert "text" not in _key_down("a", 2);
}

test "fill selects all with the platform's own shortcut" {
    assert _select_all_modifier("darwin") == 4;
    assert _select_all_modifier("linux") == 2;
    assert _select_all_modifier("win32") == 2;
}

test "Cmd edit combos carry Chromium's editing command on macOS" {
    assert _key_down("a", 4, "darwin")["commands"] == ["selectAll"];
    assert _key_down("v", 4, "darwin")["commands"] == ["paste"];
    assert _key_down("z", 4, "darwin")["commands"] == ["undo"];
    assert _key_down("z", 12, "darwin")["commands"] == ["redo"];
    assert "commands" not in _key_down("a", 2, "darwin");
    assert "commands" not in _key_down("a", 4, "linux");
    assert "commands" not in _key_down("b", 4, "darwin");
}
