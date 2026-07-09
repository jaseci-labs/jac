"""Terminal key decoding for the native TUI.

parse_key turns one raw stdin chunk (a single keypress worth of bytes)
into a structured Key. Plain bytes are classified directly (tab, enter,
backspace, ctrl, printable); an ESC lead byte defers to the escape-sequence
decoder, which recognizes the CSI/SS3 cursor families, tilde-coded editing
keys, word-motion variants, and SGR mouse wheel reports. Anything else
decodes to KeyKind.UNKNOWN so callers can drop it safely.
"""

import from .util { parse_int_or }

"""Semantic key classes produced by parse_key.

Member values are explicit on purpose: auto-valued enum members miscompare
on the native pathway (every member lowers to the same value).
"""
enum KeyKind {
    CHAR = 1,
    CTRL = 2,
    ENTER = 3,
    SHIFT_ENTER = 4,
    BACKSPACE = 5,
    DELETE = 6,
    TAB = 7,
    ESCAPE = 8,
    UP = 9,
    DOWN = 10,
    LEFT = 11,
    RIGHT = 12,
    HOME = 13,
    END = 14,
    PAGE_UP = 15,
    PAGE_DOWN = 16,
    WORD_LEFT = 17,
    WORD_RIGHT = 18,
    MOUSE_SCROLL_UP = 19,
    MOUSE_SCROLL_DOWN = 20,
    UNKNOWN = 21,
}

"""One decoded keypress; code carries the character payload as an int
(the byte for CHAR, the lowercase letter for CTRL), 0 when there is none."""
obj Key {
    has kind: KeyKind = KeyKind.UNKNOWN,
        code: int = 0;
}

# --- decode constants ---

glob _BYTE_BS: int = 8,
     _BYTE_TAB: int = 9,
     _BYTE_LF: int = 10,
     _BYTE_CR: int = 13,
     _BYTE_ESC: int = 27,
     _BYTE_DEL: int = 127;

# Ctrl-A..Ctrl-Z arrive as bytes 1..26; +96 recovers the letter 'a'..'z'.
glob _CTRL_MIN: int = 1,
     _CTRL_MAX: int = 26,
     _CTRL_TO_LOWER: int = 96,
     _PRINTABLE_MIN: int = 32,
     _PRINTABLE_MAX: int = 126;

# SGR mouse reports look like ESC [ < btn ; col ; row (M press | m release).
glob _SGR_MOUSE_PREFIX: str = "\033[<",
     _MOUSE_BTN_WHEEL_UP: int = 64,
     _MOUSE_BTN_WHEEL_DOWN: int = 65;

# Exact multi-byte escape sequences the TUI recognizes, mapped to key kind.
glob _ESC_SEQ_KIND: dict[str, KeyKind] = {
    "\033\r": KeyKind.SHIFT_ENTER,
    "\033[13;2~": KeyKind.SHIFT_ENTER,
    "\033OA": KeyKind.UP,
    "\033[A": KeyKind.UP,
    "\033OB": KeyKind.DOWN,
    "\033[B": KeyKind.DOWN,
    "\033OC": KeyKind.RIGHT,
    "\033[C": KeyKind.RIGHT,
    "\033OD": KeyKind.LEFT,
    "\033[D": KeyKind.LEFT,
    "\033OH": KeyKind.HOME,
    "\033[H": KeyKind.HOME,
    "\033OF": KeyKind.END,
    "\033[F": KeyKind.END,
    "\033[3~": KeyKind.DELETE,
    "\033[5~": KeyKind.PAGE_UP,
    "\033[1;5A": KeyKind.PAGE_UP,
    "\033[6~": KeyKind.PAGE_DOWN,
    "\033[1;5B": KeyKind.PAGE_DOWN,
    "\033[1;5D": KeyKind.WORD_LEFT,
    "\033[5D": KeyKind.WORD_LEFT,
    "\033b": KeyKind.WORD_LEFT,
    "\033[1;3D": KeyKind.WORD_LEFT,
    "\033[1;5C": KeyKind.WORD_RIGHT,
    "\033[5C": KeyKind.WORD_RIGHT,
    "\033f": KeyKind.WORD_RIGHT,
    "\033[1;3C": KeyKind.WORD_RIGHT,
};

# --- decoding ---

"""Decode an SGR mouse report; only wheel steps become keys (buttons 64/65)."""
def _parse_mouse(raw: str) -> Key {
    body = raw[len(_SGR_MOUSE_PREFIX):len(raw) - 1];
    parts = body.split(";");
    if not parts {
        return Key();
    }
    btn = parse_int_or(parts[0], -1);
    if btn == _MOUSE_BTN_WHEEL_UP {
        return Key(kind=KeyKind.MOUSE_SCROLL_UP);
    }
    if btn == _MOUSE_BTN_WHEEL_DOWN {
        return Key(kind=KeyKind.MOUSE_SCROLL_DOWN);
    }
    return Key();
}

"""Decode a chunk that starts with ESC: bare escape, mouse report, or one
of the known sequences in _ESC_SEQ_KIND."""
def _parse_escape(raw: str) -> Key {
    if len(raw) == 1 {
        return Key(kind=KeyKind.ESCAPE);
    }
    last = raw[len(raw) - 1];
    if raw.startswith(_SGR_MOUSE_PREFIX) and last in "Mm" {
        return _parse_mouse(raw);
    }
    return Key(kind=_ESC_SEQ_KIND.get(raw, KeyKind.UNKNOWN));
}

"""Classify one raw input chunk into a Key.

Single bytes map straight to kinds (tab, CR/LF -> ENTER, DEL/BS ->
BACKSPACE, 1..26 -> CTRL with code = the letter, 32..126 -> CHAR with
code = the byte); an ESC lead byte defers to the escape decoder.
"""
def parse_key(raw: str) -> Key {
    if not raw {
        return Key();
    }
    code = ord(raw[0]);
    if code == _BYTE_TAB {
        return Key(kind=KeyKind.TAB);
    }
    if code == _BYTE_CR or code == _BYTE_LF {
        return Key(kind=KeyKind.ENTER);
    }
    if code == _BYTE_DEL or code == _BYTE_BS {
        return Key(kind=KeyKind.BACKSPACE);
    }
    if code == _BYTE_ESC {
        return _parse_escape(raw);
    }
    if code >= _CTRL_MIN and code <= _CTRL_MAX {
        return Key(kind=KeyKind.CTRL, code=code + _CTRL_TO_LOWER);
    }
    if code >= _PRINTABLE_MIN and code <= _PRINTABLE_MAX {
        return Key(kind=KeyKind.CHAR, code=code);
    }
    return Key();
}
