"""`jac browse press` accepts combos such as Control+Shift+f and turns the
modifier names into CDP modifier flags (Alt 1, Control 2, Meta 4, Shift 8).
Before this the whole string went to Input.dispatchKeyEvent as the key with no
modifiers, so a page's Ctrl and Cmd shortcuts could not be driven headlessly."""

import from jaclang.cli.browser_engine { _parse_key_combo }

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
