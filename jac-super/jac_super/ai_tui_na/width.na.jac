"""Visible terminal width of strings — strips ANSI escape codes, counts UTF-8 chars.

Byte-level UTF-8 iteration; strings in NA are i8* C strings so len() returns
byte count. These helpers return visual column count for correct layout math.

Note: CJK double-wide characters are treated as width 1. Full east-asian-width
support is a future enhancement.
"""

def _is_csi_final(c: int) -> bool {
    # CSI sequence final byte: 0x40..0x7E
    return c >= 64 and c <= 126;
}

def _utf8_seq_len(lead: int) -> int {
    # Byte length of a UTF-8 sequence given its lead byte.
    if lead >= 240 {
        return 4;
    }
    if lead >= 224 {
        return 3;
    }
    if lead >= 192 {
        return 2;
    }
    return 1;
}

def visible_width(s: str) -> int {
    # Terminal columns occupied by s. ANSI escape sequences count zero.
    # UTF-8 multibyte sequences each count as 1 column.
    n = len(s);
    if n == 0 {
        return 0;
    }
    w: int = 0;
    i: int = 0;
    while i < n {
        c = ord(s[i]);
        if c == 27 {
            # ESC: skip the entire escape sequence
            if i + 1 >= n {
                i = i + 1;
                continue;
            }
            nc = ord(s[i + 1]);
            if nc == 91 {
                # CSI (ESC [): scan until final byte in 0x40..0x7E
                i = i + 2;
                while i < n and not _is_csi_final(ord(s[i])) {
                    i = i + 1;
                }
                i = i + 1;
                continue;
            }
            if nc == 93 or nc == 95 {
                # OSC (ESC ]) or APC (ESC _): scan until BEL or ESC-backslash
                i = i + 2;
                while i < n {
                    bc = ord(s[i]);
                    if bc == 7 {
                        i = i + 1;
                        break;
                    }
                    if bc == 27 and i + 1 < n and ord(s[i + 1]) == 92 {
                        i = i + 2;
                        break;
                    }
                    i = i + 1;
                }
                continue;
            }
            # Unknown ESC: skip ESC + one byte
            i = i + 2;
            continue;
        }
        if c >= 32 and c <= 126 {
            # ASCII printable: 1 column, 1 byte
            w = w + 1;
            i = i + 1;
            continue;
        }
        if c >= 194 {
            # UTF-8 multibyte lead (>= 0xC2 excludes invalid 0xC0/0xC1 overlong forms).
            # Advance by the full byte sequence length; count 1 visible column.
            seq = _utf8_seq_len(c);
            w = w + 1;
            i = i + seq;
            continue;
        }
        # 0x00-0x1F control chars, 0x7F DEL, 0x80-0xC1 continuation/invalid: skip
        i = i + 1;
    }
    return w;
}

def ansi_trunc(s: str, width: int) -> str {
    # Truncate s to at most `width` visible columns; appends ~ if clipped.
    # ANSI escape sequences are preserved up to the truncation point.
    if width <= 0 {
        return "";
    }
    if visible_width(s) <= width {
        return s;
    }
    # Copy content until we reach (width - 1) visible columns, then append ~.
    target = width - 1;
    result: str = "";
    vis: int = 0;
    i: int = 0;
    n = len(s);
    while i < n and vis < target {
        c = ord(s[i]);
        if c == 27 {
            # Escape sequence: copy through without counting width
            if i + 1 >= n {
                i = i + 1;
                continue;
            }
            nc = ord(s[i + 1]);
            if nc == 91 {
                # CSI
                j = i + 2;
                while j < n and not _is_csi_final(ord(s[j])) {
                    j = j + 1;
                }
                j = j + 1;
                result = result + s[i:j];
                i = j;
                continue;
            }
            if nc == 93 or nc == 95 {
                # OSC / APC
                j = i + 2;
                while j < n {
                    bc = ord(s[j]);
                    if bc == 7 {
                        j = j + 1;
                        break;
                    }
                    if bc == 27 and j + 1 < n and ord(s[j + 1]) == 92 {
                        j = j + 2;
                        break;
                    }
                    j = j + 1;
                }
                result = result + s[i:j];
                i = j;
                continue;
            }
            result = result + s[i:i + 2];
            i = i + 2;
            continue;
        }
        if c >= 32 and c <= 126 {
            # ASCII printable
            result = result + s[i];
            vis = vis + 1;
            i = i + 1;
            continue;
        }
        if c >= 194 {
            # UTF-8 multibyte: copy all bytes of the sequence, count 1 column
            seq = _utf8_seq_len(c);
            end_j = i + seq;
            if end_j > n {
                end_j = n;
            }
            result = result + s[i:end_j];
            vis = vis + 1;
            i = end_j;
            continue;
        }
        # Control/continuation/invalid: skip
        i = i + 1;
    }
    return result + "~";
}

def ansi_pad(s: str, width: int) -> str {
    # Pad s with trailing spaces to exactly `width` visible columns.
    # Returns s unchanged if already >= width visible columns.
    vw = visible_width(s);
    if vw >= width {
        return s;
    }
    pad = width - vw;
    result: str = s;
    i: int = 0;
    while i < pad {
        result = result + " ";
        i = i + 1;
    }
    return result;
}
