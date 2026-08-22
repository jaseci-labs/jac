def _is_space_ch(c: int) -> bool {
    return c == 9 or c == 10 or c == 11 or c == 12 or c == 13 or c == 32;
}


def _spaces(n: int) -> str {
    out: str = "";
    i: int = 0;
    while i < n {
        out += " ";
        i += 1;
    }
    return out;
}


def _cat(parts: list[str]) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(parts);
    while i < n {
        out += parts[i];
        i += 1;
    }
    return out;
}


def _sumlen(parts: list[str]) -> int {
    total: int = 0;
    i: int = 0;
    n: int = len(parts);
    while i < n {
        total += len(parts[i]);
        i += 1;
    }
    return total;
}


def _expandtabs(s: str) -> str {
    out: str = "";
    col: int = 0;
    i: int = 0;
    n: int = len(s);
    while i < n {
        ch: str = s[i];
        c: int = ord(ch);
        if c == 9 {
            pad: int = 8 - (col % 8);
            out += _spaces(pad);
            col += pad;
        } elif c == 10 or c == 13 {
            out += ch;
            col = 0;
        } else {
            out += ch;
            col += 1;
        }
        i += 1;
    }
    return out;
}


def _munge(text: str) -> str {
    expanded: str = _expandtabs(text);
    out: str = "";
    i: int = 0;
    n: int = len(expanded);
    while i < n {
        c: int = ord(expanded[i]);
        if _is_space_ch(c) {
            out += " ";
        } else {
            out += expanded[i];
        }
        i += 1;
    }
    return out;
}


def _split_chunks(s: str) -> list[str] {
    chunks: list[str] = [];
    i: int = 0;
    n: int = len(s);
    while i < n {
        sp: bool = _is_space_ch(ord(s[i]));
        j: int = i;
        while j < n and _is_space_ch(ord(s[j])) == sp {
            j += 1;
        }
        chunks.append(s[i:j]);
        i = j;
    }
    return chunks;
}


def _wrap_chunks(chunks: list[str], width: int) -> list[str] {
    lines: list[str] = [];
    if width <= 0 {
        raise ValueError("invalid width " + str(width) + " (must be > 0)");
    }
    pos: int = 0;
    n: int = len(chunks);
    while pos < n {
        cur: list[str] = [];
        cur_len: int = 0;
        w: int = width;

        if len(lines) > 0 and pos < n and chunks[pos].strip() == "" {
            pos += 1;
        }
        while pos < n {
            l: int = len(chunks[pos]);
            if cur_len + l <= w {
                cur.append(chunks[pos]);
                pos += 1;
                cur_len += l;
            } else {
                break;
            }
        }

        if pos < n and len(chunks[pos]) > w {
            space_left: int = 1 if w < 1 else w - cur_len;
            if space_left > 0 {
                chunk: str = chunks[pos];
                cur.append(chunk[0:space_left]);
                chunks[pos] = chunk[space_left:];
                cur_len = _sumlen(cur);
            } elif len(cur) == 0 {
                cur.append(chunks[pos]);
                pos += 1;
                cur_len = _sumlen(cur);
            }
        }

        if len(cur) > 0 and cur[len(cur) - 1].strip() == "" {
            cur.pop();
        }
        if len(cur) > 0 {
            lines.append(_cat(cur));
        }
    }
    return lines;
}


def:pub wrap(text: str, width: int = 70) -> list[str] {
    return _wrap_chunks(_split_chunks(_munge(text)), width);
}


def:pub fill(text: str, width: int = 70) -> str {
    lines: list[str] = wrap(text, width);
    out: str = "";
    i: int = 0;
    n: int = len(lines);
    while i < n {
        if i > 0 {
            out += "\n";
        }
        out += lines[i];
        i += 1;
    }
    return out;
}


def _leading_ws(s: str) -> str {
    i: int = 0;
    n: int = len(s);
    while i < n {
        c: int = ord(s[i]);
        if c == 32 or c == 9 {
            i += 1;
        } else {
            break;
        }
    }
    return s[0:i];
}


def _common_prefix(a: str, b: str) -> str {
    i: int = 0;
    m: int = len(a);
    if len(b) < m {
        m = len(b);
    }
    while i < m and a[i] == b[i] {
        i += 1;
    }
    return a[0:i];
}


def:pub dedent(text: str) -> str {
    lines: list[str] = text.split("\n");
    common: str = "";
    first: bool = True;
    i: int = 0;
    n: int = len(lines);
    while i < n {
        line: str = lines[i];
        if line.strip() != "" {
            lead: str = _leading_ws(line);
            if first {
                common = lead;
                first = False;
            } else {
                common = _common_prefix(common, lead);
            }
        }
        i += 1;
    }
    margin: int = len(common);
    out: str = "";
    j: int = 0;
    while j < n {
        if j > 0 {
            out += "\n";
        }
        line2: str = lines[j];
        if line2.strip() == "" {
            out += "";
        } else {
            out += line2[margin:];
        }
        j += 1;
    }
    return out;
}


def _splitlines_keepends(text: str) -> list[str] {
    parts: list[str] = [];
    start: int = 0;
    i: int = 0;
    n: int = len(text);
    while i < n {
        if text[i] == "\n" {
            parts.append(text[start:i + 1]);
            start = i + 1;
        }
        i += 1;
    }
    if start < n {
        parts.append(text[start:n]);
    }
    return parts;
}


def:pub indent(text: str, prefix: str) -> str {
    out: str = "";
    parts: list[str] = _splitlines_keepends(text);
    i: int = 0;
    n: int = len(parts);
    while i < n {
        line: str = parts[i];
        if line.strip() != "" {
            out += prefix;
        }
        out += line;
        i += 1;
    }
    return out;
}
