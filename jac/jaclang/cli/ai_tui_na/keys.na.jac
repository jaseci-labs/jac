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

obj Key {
    has kind: int = 0,
        code: int = 0;
}

glob KK_CHAR: int = 1,
     KK_CTRL: int = 2,
     KK_ENTER: int = 3,
     KK_SHIFT_ENTER: int = 4,
     KK_BACKSPACE: int = 5,
     KK_DELETE: int = 6,
     KK_TAB: int = 7,
     KK_ESCAPE: int = 8,
     KK_UP: int = 9,
     KK_DOWN: int = 10,
     KK_LEFT: int = 11,
     KK_RIGHT: int = 12,
     KK_HOME: int = 13,
     KK_END: int = 14,
     KK_PAGE_UP: int = 15,
     KK_PAGE_DOWN: int = 16,
     KK_WORD_LEFT: int = 17,
     KK_WORD_RIGHT: int = 18,
     KK_MOUSE_SCROLL_UP: int = 19,
     KK_MOUSE_SCROLL_DOWN: int = 20,
     KK_UNKNOWN: int = 21;

def _parse_uint(s: str) -> int {
    n: int = 0;
    i: int = 0;
    m = len(s);
    while i < m {
        c = ord(s[i]);
        if c >= 48 and c <= 57 {
            n = n * 10 + (c - 48);
        }
        i = i + 1;
    }
    return n;
}

def parse_key(raw: str) -> Key {
    if len(raw) == 0 {
        k = Key();
        k.kind = KK_UNKNOWN;
        return k;
    }

    first = raw[0];
    code = ord(first);

    if code == 9 {
        k = Key();
        k.kind = KK_TAB;
        return k;
    }
    if code == 13 or code == 10 {
        k = Key();
        k.kind = KK_ENTER;
        return k;
    }
    if code == 127 or code == 8 {
        k = Key();
        k.kind = KK_BACKSPACE;
        return k;
    }

    if code == 27 {
        if len(raw) == 1 {
            k = Key();
            k.kind = KK_ESCAPE;
            return k;
        }

        last = raw[len(raw) - 1];

        if raw.startswith("\033[<") and (last == "M" or last == "m") {
            parts = raw[3:len(raw) - 1].split(";");
            if len(parts) > 0 {
                btn = _parse_uint(parts[0]);
                if btn == 64 {
                    k = Key();
                    k.kind = KK_MOUSE_SCROLL_UP;
                    return k;
                }
                if btn == 65 {
                    k = Key();
                    k.kind = KK_MOUSE_SCROLL_DOWN;
                    return k;
                }
            }
            k = Key();
            k.kind = KK_UNKNOWN;
            return k;
        }

        if raw == "\033\r" or raw == "\033[13;2~" {
            k = Key();
            k.kind = KK_SHIFT_ENTER;
            return k;
        }

        if raw == "\033OA" or raw == "\033[A" {
            k = Key();
            k.kind = KK_UP;
            return k;
        }
        if raw == "\033OB" or raw == "\033[B" {
            k = Key();
            k.kind = KK_DOWN;
            return k;
        }
        if raw == "\033OC" or raw == "\033[C" {
            k = Key();
            k.kind = KK_RIGHT;
            return k;
        }
        if raw == "\033OD" or raw == "\033[D" {
            k = Key();
            k.kind = KK_LEFT;
            return k;
        }
        if raw == "\033OH" or raw == "\033[H" {
            k = Key();
            k.kind = KK_HOME;
            return k;
        }
        if raw == "\033OF" or raw == "\033[F" {
            k = Key();
            k.kind = KK_END;
            return k;
        }

        if raw == "\033[3~" {
            k = Key();
            k.kind = KK_DELETE;
            return k;
        }

        if raw == "\033[5~" or raw == "\033[1;5A" {
            k = Key();
            k.kind = KK_PAGE_UP;
            return k;
        }
        if raw == "\033[6~" or raw == "\033[1;5B" {
            k = Key();
            k.kind = KK_PAGE_DOWN;
            return k;
        }

        if raw == "\033[1;5D"
        or raw == "\033[5D"
        or raw == "\033b"
        or raw == "\033[1;3D" {
            k = Key();
            k.kind = KK_WORD_LEFT;
            return k;
        }
        if raw == "\033[1;5C"
        or raw == "\033[5C"
        or raw == "\033f"
        or raw == "\033[1;3C" {
            k = Key();
            k.kind = KK_WORD_RIGHT;
            return k;
        }

        k = Key();
        k.kind = KK_UNKNOWN;
        return k;
    }

    if code >= 1 and code <= 26 {
        k = Key();
        k.kind = KK_CTRL;
        k.code = code + 96;
        return k;
    }

    if code >= 32 and code <= 126 {
        k = Key();
        k.kind = KK_CHAR;
        k.code = code;
        return k;
    }

    k = Key();
    k.kind = KK_UNKNOWN;
    return k;
}
