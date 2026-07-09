"""Byte-oriented visible-width math for ANSI-styled terminal strings.

The package contract is deliberately byte-oriented (len(str) is bytes on
na): printable ASCII counts one column, ANSI escape sequences count zero,
and any UTF-8 lead byte >= 194 counts exactly one column with its
continuation bytes skipped — no East-Asian double-width handling.
Every widget's truncate/pad cell math relies on these exact semantics.
"""

# --- byte codes and thresholds ---

glob _ESC_BYTE: int = 27,
     _BEL_BYTE: int = 7,
     _CSI_INTRO: int = 91,
     _OSC_INTRO: int = 93,
     _APC_INTRO: int = 95,
     _ST_BACKSLASH: int = 92;

glob _ASCII_PRINT_LO: int = 32,
     _ASCII_PRINT_HI: int = 126,
     _CSI_FINAL_LO: int = 64,
     _CSI_FINAL_HI: int = 126;

# UTF-8 lead-byte thresholds; >= _UTF8_LEAD_MIN is one visible column.
glob _UTF8_LEAD_MIN: int = 194,
     _UTF8_LEAD_4: int = 240,
     _UTF8_LEAD_3: int = 224,
     _UTF8_LEAD_2: int = 192;

glob _TRUNC_MARK: str = "~";

# --- exported helpers ---

"""Integer division that returns 0 for any non-positive divisor.

Callers (editor/screen layout math) divide by terminal dimensions that
can legitimately be 0 during startup or resize — the guard is contract.
"""
def idiv(a: int, b: int) -> int {
    if b <= 0 {
        return 0;
    }
    return a // b;
}

"""True when byte code c ('@'..'~') terminates a CSI sequence."""
def _is_csi_final(c: int) -> bool {
    return c >= _CSI_FINAL_LO and c <= _CSI_FINAL_HI;
}

"""Total byte length (1-4) of the UTF-8 sequence starting with lead."""
def _utf8_seq_len(lead: int) -> int {
    if lead >= _UTF8_LEAD_4 {
        return 4;
    }
    if lead >= _UTF8_LEAD_3 {
        return 3;
    }
    if lead >= _UTF8_LEAD_2 {
        return 2;
    }
    return 1;
}

"""Return the index just past the escape sequence whose ESC is at s[i].

Handles CSI (ESC [ .. final byte), OSC/APC (ESC ]/_ .. BEL or ESC \\),
and treats anything else as a two-byte ESC+char sequence.
"""
def _skip_ansi_at(s: str, i: int) -> int {
    n = len(s);
    if i + 1 >= n {
        return i + 1;
    }
    intro = ord(s[i + 1]);
    if intro == _CSI_INTRO {
        j = i + 2;
        while j < n and not _is_csi_final(ord(s[j])) {
            j += 1;
        }
        return j + 1;
    }
    if intro == _OSC_INTRO or intro == _APC_INTRO {
        j = i + 2;
        while j < n {
            bc = ord(s[j]);
            if bc == _BEL_BYTE {
                return j + 1;
            }
            if bc == _ESC_BYTE and j + 1 < n and ord(s[j + 1]) == _ST_BACKSLASH {
                return j + 2;
            }
            j += 1;
        }
        return j;
    }
    return i + 2;
}

"""Count the terminal columns s occupies, ignoring ANSI escapes.

Byte-oriented package contract: printable ASCII and each UTF-8 lead
byte >= 194 count one column; control and continuation bytes count zero.
"""
def visible_width(s: str) -> int {
    n = len(s);
    if n == 0 {
        return 0;
    }
    w: int = 0;
    i: int = 0;
    # Manual index walk: advance is variable-length (escapes, UTF-8 runs).
    while i < n {
        c = ord(s[i]);
        if c == _ESC_BYTE {
            i = _skip_ansi_at(s, i);
            continue;
        }
        if c >= _ASCII_PRINT_LO and c <= _ASCII_PRINT_HI {
            w += 1;
            i += 1;
            continue;
        }
        if c >= _UTF8_LEAD_MIN {
            w += 1;
            i += _utf8_seq_len(c);
            continue;
        }
        i += 1;
    }
    return w;
}

"""Truncate s to at most width visible columns, preserving ANSI escapes.

Strings that already fit are returned unchanged; otherwise the last
column is spent on the "~" truncation marker. Escape sequences before
the cut point are kept intact so styling survives truncation.
"""
def ansi_trunc(s: str, width: int) -> str {
    if width <= 0 {
        return "";
    }
    if visible_width(s) <= width {
        return s;
    }
    target = width - 1;  # reserve one column for the truncation marker
    parts: list[str] = [];
    vis: int = 0;
    i: int = 0;
    n = len(s);
    while i < n and vis < target {
        c = ord(s[i]);
        if c == _ESC_BYTE {
            j = _skip_ansi_at(s, i);
            parts.append(s[i:j]);
            i = j;
            continue;
        }
        if c >= _ASCII_PRINT_LO and c <= _ASCII_PRINT_HI {
            parts.append(s[i]);
            vis += 1;
            i += 1;
            continue;
        }
        if c >= _UTF8_LEAD_MIN {
            end_j = min(i + _utf8_seq_len(c), n);
            parts.append(s[i:end_j]);
            vis += 1;
            i = end_j;
            continue;
        }
        i += 1;
    }
    return "".join(parts) + _TRUNC_MARK;
}

"""Right-pad s with spaces to width visible columns (no-op if it fits)."""
def ansi_pad(s: str, width: int) -> str {
    vw = visible_width(s);
    if vw >= width {
        return s;  # also guards the negative-count repetition below
    }
    return s + " " * (width - vw);
}
