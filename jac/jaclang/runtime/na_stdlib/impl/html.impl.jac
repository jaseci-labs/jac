impl escape(s: str, quote: bool = True) -> str {
    s = s.replace("&", "&amp;");
    s = s.replace("<", "&lt;");
    s = s.replace(">", "&gt;");
    if quote {
        s = s.replace("\"", "&quot;");
        s = s.replace("'", "&#x27;");
    }
    return s;
}

impl unescape(s: str) -> str {
    if "&" not in s {
        return s;
    }
    out: str = "";
    n: int = len(s);
    i: int = 0;
    while i < n {
        if s[i] != "&" {
            out += s[i];
            i += 1;
            continue;
        }
        end: int = _charref_end(s, i + 1);
        if end < 0 {
            out += "&";
            i += 1;
            continue;
        }
        out += _replace_charref(s[i + 1:end]);
        i = end;
    }
    return out;
}

impl _is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

impl _is_hex(ch: str) -> bool {
    return _is_digit(ch) or (ch >= "a" and ch <= "f") or (ch >= "A" and ch <= "F");
}

impl _charref_end(s: str, start: int) -> int {
    n: int = len(s);
    if start >= n {
        return -1;
    }
    if s[start] == "#" {
        j: int = start + 1;
        if j < n and _is_digit(s[j]) {
            while j < n and _is_digit(s[j]) {
                j += 1;
            }
            return j + 1 if j < n and s[j] == ";" else j;
        }
        if j < n and (s[j] == "x" or s[j] == "X") and j + 1 < n and _is_hex(s[j + 1]) {
            j += 1;
            while j < n and _is_hex(s[j]) {
                j += 1;
            }
            return j + 1 if j < n and s[j] == ";" else j;
        }
        return -1;
    }
    k: int = start;
    while k < n and k - start < _MAX_NAME and s[k] not in _NAMED_SET {
        k += 1;
    }
    if k == start {
        return -1;
    }
    return k + 1 if k < n and s[k] == ";" else k;
}

impl _charref_number(digits: str, base: int) -> int {
    value: int = 0;
    for ch in digits {
        if ch == ";" {
            break;
        }
        if _is_digit(ch) {
            value = value * base + (ord(ch) - 48);
        } elif ch >= "a" and ch <= "f" {
            value = value * base + (ord(ch) - 87);
        } else {
            value = value * base + (ord(ch) - 55);
        }
        if value > 1114111 {
            return 1114112;
        }
    }
    return value;
}

impl _replace_charref(ref: str) -> str {
    if ref[0] == "#" {
        num: int = 0;
        if ref[1] == "x" or ref[1] == "X" {
            num = _charref_number(ref[2:], 16);
        } else {
            num = _charref_number(ref[1:], 10);
        }
        if num in _INVALID_CHARREFS {
            return _INVALID_CHARREFS[num];
        }
        if (num >= 55296 and num <= 57343) or num > 1114111 {
            return _REPLACEMENT;
        }
        if num in _INVALID_CODEPOINTS {
            return "";
        }
        return chr(num);
    }
    if ref in _HTML5 {
        return _HTML5[ref];
    }
    x: int = len(ref) - 1;
    while x > 1 {
        head: str = ref[:x];
        if head in _HTML5 {
            return _HTML5[head] + ref[x:];
        }
        x -= 1;
    }
    return "&" + ref;
}
