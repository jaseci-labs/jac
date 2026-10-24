import from unicodedata { east_asian_width, category }


obj Grapheme {
    has text: str = "",
        index: int = 0;
}


def _is_mark(cat: str) -> bool;


def _is_non_printing(cat: str) -> bool;


def _char_east_asian_cols(cp: int) -> int;


def _is_regional_indicator(cp: int) -> bool;


def _is_variation_selector(cp: int) -> bool;


def _is_emojiish(seg: str) -> bool;


def _strip_leading_non_printing(seg: str) -> str;


def _is_zero_width_segment(seg: str) -> bool;


def segment_graphemes(text: str) -> list[Grapheme];


def grapheme_width(seg: str) -> int;


obj AnsiToken {
    has code: str = "",
        length: int = 0;
}


def extract_ansi(text: str, pos: int) -> AnsiToken | None;


def strip_ansi(text: str) -> str;


def _is_printable_ascii(text: str) -> bool;


def display_width(text: str) -> int;


def _simple_char_width(ch: str) -> int;


glob _CHAR_WIDTHS: dict[str, int] = {};


obj TruncatedSpan {
    has text: str = "",
        width: int = 0;
}


def _truncate_plain(text: str, max_width: int) -> TruncatedSpan;


def truncate_text(
    text: str, max_width: int, ellipsis: str = "...", pad: bool = False,
) -> str;


def wrap_text(text: str, width: int) -> list[str];


def wrap_text_joined(text: str, width: int) -> str;


def wrap_words(text: str, width: int) -> list[str];

impl _is_mark(cat: str) -> bool {
    return cat == "Mn" or cat == "Mc" or cat == "Me";
}


impl _is_non_printing(cat: str) -> bool {
    return (cat == "Cc" or cat == "Cf" or cat == "Cs" or _is_mark(cat));
}


impl _char_east_asian_cols(cp: int) -> int {
    w = east_asian_width(chr(cp));
    if w == "W" or w == "F" {
        return 2;
    }
    return 1;
}


impl _is_regional_indicator(cp: int) -> bool {
    return cp >= 0x1F1E6 and cp <= 0x1F1FF;
}


impl _is_variation_selector(cp: int) -> bool {
    return (cp >= 0xFE00 and cp <= 0xFE0F) or (cp >= 0xE0100 and cp <= 0xE01EF);
}


impl _is_emojiish(seg: str) -> bool {
    if not seg {
        return False;
    }
    for ch in seg {
        cp = ord(ch);
        if cp == 0xFE0F or cp == 0x200D or _is_regional_indicator(cp) {
            return True;
        }
        if cp >= 0x1F300 and cp <= 0x1FAFF {
            return True;
        }
    }
    return False;
}


impl _strip_leading_non_printing(seg: str) -> str {
    i = 0;
    while i < len(seg) and _is_non_printing(category(seg[i])) {
        i += 1;
    }
    return seg[i:];
}


impl _is_zero_width_segment(seg: str) -> bool {
    if not seg {
        return False;
    }
    for ch in seg {
        if not _is_non_printing(category(ch)) {
            return False;
        }
    }
    return True;
}


impl segment_graphemes(text: str) -> list[Grapheme] {
    out: list[Grapheme] = [];
    n = len(text);
    i = 0;
    while i < n {
        start = i;
        first = ord(text[i]);
        i += 1;
        if _is_regional_indicator(first) {
            if i < n and _is_regional_indicator(ord(text[i])) {
                i += 1;
            }
        }
        cont = True;
        while i < n and cont {
            cp = ord(text[i]);
            prev = ord(text[i - 1]);
            cat = category(text[i]);
            extend = (
                _is_mark(cat)
                or _is_variation_selector(cp)
                or cp == 0x200D
                or prev == 0x200D
            );
            if extend {
                i += 1;
            } else {
                cont = False;
            }
        }
        out.append(Grapheme(text=text[start:i], index=start));
    }
    return out;
}


impl grapheme_width(seg: str) -> int {
    if not seg {
        return 0;
    }
    if seg == "\t" {
        return 3;
    }
    if _is_zero_width_segment(seg) {
        return 0;
    }
    if _is_emojiish(seg) {
        return 2;
    }
    base = _strip_leading_non_printing(seg);
    if not base {
        return 0;
    }
    cp = ord(base[0]);
    if _is_regional_indicator(cp) {
        return 2;
    }
    width = _char_east_asian_cols(cp);
    if len(seg) > 1 {
        for ch in seg[1:] {
            c = ord(ch);

            if c >= 0xFF00 and c <= 0xFFEF {
                width += _char_east_asian_cols(c);
            }
        }
    }
    return width;
}


impl extract_ansi(text: str, pos: int) -> AnsiToken | None {
    if pos >= len(text) or text[pos] != "\x1b" {
        return None;
    }
    if pos + 1 >= len(text) {
        return None;
    }
    nxt = text[pos + 1];
    if nxt == "[" {
        j = pos + 2;
        while j < len(text) {
            code = ord(text[j]);
            if code >= 64 and code <= 126 {
                return AnsiToken(code=text[pos:j + 1], length=(j + 1) - pos);
            }
            j += 1;
        }
        return None;
    }
    if nxt == "]" {
        j = pos + 2;
        while j < len(text) {
            if text[j] == "\x07" {
                return AnsiToken(code=text[pos:j + 1], length=(j + 1) - pos);
            }
            if text[j] == "\x1b" and j + 1 < len(text) and text[j + 1] == "\\" {
                return AnsiToken(code=text[pos:j + 2], length=(j + 2) - pos);
            }
            j += 1;
        }
        return None;
    }
    if nxt == "_" or nxt == "P" {
        j = pos + 2;
        while j < len(text) {
            if text[j] == "\x07" {
                return AnsiToken(code=text[pos:j + 1], length=(j + 1) - pos);
            }
            if text[j] == "\x1b" and j + 1 < len(text) and text[j + 1] == "\\" {
                return AnsiToken(code=text[pos:j + 2], length=(j + 2) - pos);
            }
            j += 1;
        }
        return None;
    }

    return AnsiToken(code=text[pos:pos + 2], length=2);
}


impl strip_ansi(text: str) -> str {
    out = "";
    i = 0;
    while i < len(text) {
        ansi = extract_ansi(text, i);
        if ansi is not None {
            i += ansi.length;
            continue;
        }
        out += text[i];
        i += 1;
    }
    return out;
}


impl _is_printable_ascii(text: str) -> bool {
    return text.isascii() and text.isprintable();
}


impl display_width(text: str) -> int {
    if not text {
        return 0;
    }
    if "\x1b" not in text and "\t" not in text {
        if _is_printable_ascii(text) {
            return len(text);
        }
        total = 0;
        simple = True;
        for ch in text {
            w = _CHAR_WIDTHS.get(ch, -2);
            if w == -2 {
                w = _simple_char_width(ch);
                _CHAR_WIDTHS[ch] = w;
            }
            if w < 0 {
                simple = False;
                break;
            }
            total += w;
        }
        if simple {
            return total;
        }
    }
    clean = text;
    if "\t" in clean {
        clean = clean.replace("\t", "   ");
    }
    if "\x1b" in clean {
        clean = strip_ansi(clean);
    }
    width = 0;
    for g in segment_graphemes(clean) {
        width += grapheme_width(g.text);
    }
    return width;
}


impl _truncate_plain(text: str, max_width: int) -> TruncatedSpan {
    if max_width <= 0 or not text {
        return TruncatedSpan(text="", width=0);
    }
    if _is_printable_ascii(text) and "\x1b" not in text and "\t" not in text {
        clipped = text[0:max_width];
        return TruncatedSpan(text=clipped, width=len(clipped));
    }
    result = "";
    width = 0;
    i = 0;
    pending_ansi = "";
    while i < len(text) {
        ansi = extract_ansi(text, i);
        if ansi is not None {
            pending_ansi += ansi.code;
            i += ansi.length;
            continue;
        }

        end = i + 1;
        while end < len(text) and extract_ansi(text, end) is None {
            end += 1;
        }
        for g in segment_graphemes(text[i:end]) {
            w = grapheme_width(g.text);
            if width + w > max_width {
                return TruncatedSpan(text=result, width=width);
            }
            if pending_ansi {
                result += pending_ansi;
                pending_ansi = "";
            }
            result += g.text;
            width += w;
        }
        i = end;
    }
    if pending_ansi {
        result += pending_ansi;
    }
    return TruncatedSpan(text=result, width=width);
}


impl truncate_text(
    text: str, max_width: int, ellipsis: str = "...", pad: bool = False,
) -> str {
    if max_width <= 0 {
        return "";
    }
    if not text {
        return (" " * max_width) if pad else "";
    }
    ellipsis_w = display_width(ellipsis);
    text_w = display_width(text);
    if text_w <= max_width {
        if pad {
            return text + (" " * (max_width - text_w));
        }
        return text;
    }
    if ellipsis_w >= max_width {
        clipped = _truncate_plain(ellipsis, max_width);
        body = clipped.text;
        if pad {
            return body + (" " * (max_width - clipped.width));
        }
        return body;
    }
    target = max_width - ellipsis_w;
    clipped = _truncate_plain(text, target);
    body = clipped.text + ellipsis;
    if pad {
        return body + (" " * (max_width - display_width(body)));
    }
    return body;
}


impl wrap_text(text: str, width: int) -> list[str] {
    if width <= 0 {
        return [""];
    }
    if not text {
        return [""];
    }
    result: list[str] = [];
    for line in text.split("\n") {
        if display_width(line) <= width {
            result.append(line);
            continue;
        }
        current = "";
        current_w = 0;
        i = 0;
        while i < len(line) {
            ansi = extract_ansi(line, i);
            if ansi is not None {
                current += ansi.code;
                i += ansi.length;
                continue;
            }
            end = i + 1;
            while end < len(line) and extract_ansi(line, end) is None {
                end += 1;
            }
            for g in segment_graphemes(line[i:end]) {
                w = grapheme_width(g.text);
                if current_w > 0 and current_w + w > width {
                    result.append(current);
                    current = "";
                    current_w = 0;
                }

                if w > width and current_w == 0 {
                    result.append(g.text);
                    continue;
                }
                current += g.text;
                current_w += w;
            }
            i = end;
        }
        if current or not result {
            result.append(current);
        }
    }
    return result or [""];
}


impl wrap_text_joined(text: str, width: int) -> str {
    return "\n".join(wrap_text(text, width));
}


impl _simple_char_width(ch: str) -> int {
    cp = ord(ch);
    if cp < 32 or cp == 0x7F {
        return -1;
    }
    if _is_non_printing(category(ch))
        or _is_variation_selector(cp)
        or _is_regional_indicator(cp)
        or (cp >= 0x1F300 and cp <= 0x1FAFF)
        or (cp >= 0x1100 and cp <= 0x11FF) {
        return -1;
    }
    return grapheme_width(ch);
}


impl wrap_words(text: str, width: int) -> list[str] {
    if width <= 0 {
        return [""];
    }
    out: list[str] = [];
    for para in text.split("\n") {
        body = para.lstrip(" ");
        indent = para[:len(para) - len(body)];
        room = max(1, width - display_width(indent));
        line = "";
        used = 0;
        for word in body.split(" ") {
            ww = display_width(word);
            sep = 1 if line else 0;
            if line and used + sep + ww > room {
                out.append(indent + line);
                line = "";
                used = 0;
                sep = 0;
            }
            if ww > room {
                for piece in wrap_text(word, room) {
                    if line {
                        out.append(indent + line);
                    }
                    line = piece;
                    used = display_width(piece);
                }
                continue;
            }
            line = line + (" " if sep else "") + word;
            used += sep + ww;
        }
        out.append(indent + line);
    }
    return out;
}
