import from .terminal {
    ANSI_BOLD,
    ANSI_FG_YELLOW,
    ANSI_ITALIC,
    ANSI_RESET,
    ANSI_STRIKE,
    Rgb,
    ansi_sgr,
    term_spaces,
    term_dashes
}
import from .width { visible_width, ansi_pad }
import from .terminal_image { term_hyperlink }
import from .theme {
    TH_BG,
    TH_SGR_MD_H1,
    TH_SGR_MD_H2,
    TH_SGR_MD_H3,
    TH_SGR_MD_CODE,
    TH_SGR_MD_FENCE,
    TH_SGR_MD_BQ,
    TH_SGR_MD_BQ_BAR,
    TH_SGR_MD_HR
}

glob _HR_MAX_COLS: int = 80;

def _md_is_blank(s: str) -> bool {
    return s.strip(" \t\r") == "";
}

def _md_is_fence(s: str) -> bool {
    return s.startswith("```");
}

def _md_fence_lang(s: str) -> str {
    tag = s[3:];
    return tag.lstrip(" \t");
}

def _md_heading_level(s: str) -> int {
    if s.startswith("### ") {
        return 3;
    }
    if s.startswith("## ") {
        return 2;
    }
    if s.startswith("# ") {
        return 1;
    }
    return 0;
}

def _md_is_hr(s: str) -> bool {
    if len(s) < 3 {
        return False;
    }
    mark = s[0];
    if mark not in "-_*" {
        return False;
    }
    marks = s.replace(" ", "");
    return len(marks) >= 3 and marks == mark * len(marks);
}

def _md_is_ul(s: str) -> bool {
    if len(s) < 2 {
        return False;
    }
    return s[0] in "-*+" and s[1] == " ";
}

def _md_ol_marker_end(s: str) -> int {
    n = len(s);
    digits: int = 0;
    while digits < n and s[digits].isdigit() {
        digits += 1;
    }
    if digits == 0 or digits + 1 >= n {
        return -1;
    }
    if s[digits] == "." and s[digits + 1] == " " {
        return digits + 2;
    }
    return -1;
}

def _md_is_bq(s: str) -> bool {
    return s.startswith(">");
}

def _md_bq_text(s: str) -> str {
    return s[2:] if s.startswith("> ") else s[1:];
}

def _md_find_close(s: str, start: int, delim: str) -> int {
    tail = s[start:];
    at = tail.find(delim);
    return start + at if at >= 0 else -1;
}

def _md_apply_inline(s: str, base_sgr: str) -> str {
    result: str = "";
    n = len(s);
    i: int = 0;
    while i < n {
        c = s[i];

        if c == "`" {
            close_at = _md_find_close(s, i + 1, "`");
            if close_at >= 0 {
                result = result + ANSI_FG_YELLOW + s[i + 1:close_at] + ANSI_RESET + base_sgr;
                i = close_at + 1;
                continue;
            }
        }

        if c == "*" and i + 1 < n and s[i + 1] == "*" {
            close_at = _md_find_close(s, i + 2, "**");
            if close_at >= 0 {
                result = result + ANSI_BOLD + s[i + 2:close_at] + ANSI_RESET + base_sgr;
                i = close_at + 2;
                continue;
            }
        }

        if c == "*" and (i + 1 >= n or s[i + 1] != "*") {
            close_at = _md_find_close(s, i + 1, "*");
            if close_at > i + 1 {
                result = result + ANSI_ITALIC + s[i + 1:close_at] + ANSI_RESET + base_sgr;
                i = close_at + 1;
                continue;
            }
        }

        if c == "~" and i + 1 < n and s[i + 1] == "~" {
            close_at = _md_find_close(s, i + 2, "~~");
            if close_at >= 0 {
                result = result + ANSI_STRIKE + s[i + 2:close_at] + ANSI_RESET + base_sgr;
                i = close_at + 2;
                continue;
            }
        }

        if c == "[" {
            close_bracket = _md_find_close(s, i + 1, "]");
            if (
                close_bracket > i
                and close_bracket + 1 < n
                and s[close_bracket + 1] == "("
            ) {
                close_paren = _md_find_close(s, close_bracket + 2, ")");
                if close_paren > close_bracket + 1 {
                    link_text = s[i + 1:close_bracket];
                    link_url = s[close_bracket + 2:close_paren];
                    result = result + term_hyperlink(link_text, link_url);
                    i = close_paren + 1;
                    continue;
                }
            }
        }

        result = result + s[i];
        i += 1;
    }
    return result;
}

def _md_wrap(styled: str, width: int, base_sgr: str) -> list[str] {
    rows: list[str] = [];
    current: str = "";
    current_w: int = 0;
    words = styled.split(" ");

    word_count = len(words);
    wi: int = 0;
    while wi < word_count {
        word = words[wi];
        wi += 1;
        word_w = visible_width(word);
        if current_w == 0 {
            current = word;
            current_w = word_w;
        } elif current_w + 1 + word_w <= width {
            current = current + " " + word;
            current_w += 1 + word_w;
        } else {
            rows.append(base_sgr + ansi_pad(current, width) + ANSI_RESET);
            current = word;
            current_w = word_w;
        }
    }

    if current_w > 0 or len(rows) == 0 {
        rows.append(base_sgr + ansi_pad(current, width) + ANSI_RESET);
    }
    return rows;
}

def _md_emit_wrapped(
    wrapped: list[str], out: list[str], sgr: str, first_prefix: str, cont_prefix: str
) {
    n = len(wrapped);
    i: int = 0;
    while i < n {
        if i == 0 {
            out.append(sgr + first_prefix + wrapped[i]);
        } else {
            out.append(sgr + cont_prefix + wrapped[i]);
        }
        i += 1;
    }
}

def md_render(text: str, width: int, color: Rgb, attrs: int) -> list[str] {
    base_sgr = ansi_sgr(color, TH_BG, attrs);
    result: list[str] = [];
    in_fence: bool = False;

    lines = text.split("\n");
    line_count = len(lines);
    line_idx: int = 0;
    while line_idx < line_count {
        line = lines[line_idx];
        line_idx += 1;
        ll = len(line);
        if ll > 0 and line[ll - 1] == "\r" {
            line = line[:ll - 1];
        }

        if in_fence {
            if _md_is_fence(line) {
                close_row = TH_SGR_MD_FENCE + "```";
                result.append(ansi_pad(close_row, width) + ANSI_RESET);
                in_fence = False;
            } else {
                code_row = TH_SGR_MD_CODE + "  " + line;
                result.append(ansi_pad(code_row, width) + ANSI_RESET);
            }
            continue;
        }

        if _md_is_blank(line) {
            result.append(base_sgr + ansi_pad("", width) + ANSI_RESET);
            continue;
        }

        if _md_is_fence(line) {
            open_row = TH_SGR_MD_FENCE + "```" + _md_fence_lang(line);
            result.append(ansi_pad(open_row, width) + ANSI_RESET);
            in_fence = True;
            continue;
        }

        lvl = _md_heading_level(line);
        if lvl > 0 {
            h_sgr = TH_SGR_MD_H1;
            if lvl == 2 {
                h_sgr = TH_SGR_MD_H2;
            }
            if lvl == 3 {
                h_sgr = TH_SGR_MD_H3;
            }
            h_text = line[lvl + 1:];
            styled = _md_apply_inline(h_text, h_sgr);
            wrapped = _md_wrap(styled, width, h_sgr);
            result.extend(wrapped);
            continue;
        }

        if _md_is_hr(line) {
            rule = TH_SGR_MD_HR + term_dashes(min(width, _HR_MAX_COLS));
            result.append(ansi_pad(rule, width) + ANSI_RESET);
            continue;
        }

        if _md_is_ul(line) {
            body = line[2:];
            styled = _md_apply_inline(body, base_sgr);
            wrapped = _md_wrap(styled, max(1, width - 2), base_sgr);
            _md_emit_wrapped(wrapped, result, base_sgr, "• ", "  ");
            continue;
        }

        marker_end = _md_ol_marker_end(line);
        if marker_end >= 0 {
            marker = line[:marker_end];
            body = line[marker_end:];
            marker_cols = len(marker);
            cont_pad = term_spaces(marker_cols);
            styled = _md_apply_inline(body, base_sgr);
            wrapped = _md_wrap(styled, max(1, width - marker_cols), base_sgr);
            _md_emit_wrapped(wrapped, result, base_sgr, marker, cont_pad);
            continue;
        }

        if _md_is_bq(line) {
            quote = _md_bq_text(line);
            styled = _md_apply_inline(quote, TH_SGR_MD_BQ);
            wrapped = _md_wrap(styled, max(1, width - 2), TH_SGR_MD_BQ);
            _md_emit_wrapped(wrapped, result, TH_SGR_MD_BQ_BAR, "│ ", "│ ");
            continue;
        }

        styled = _md_apply_inline(line, base_sgr);
        wrapped = _md_wrap(styled, width, base_sgr);
        result.extend(wrapped);
    }

    return result;
}
