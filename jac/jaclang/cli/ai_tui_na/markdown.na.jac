"""Minimal markdown renderer: text -> ANSI-styled terminal rows.

Each row is padded to `width` visible columns and self-contained (starts with
the base SGR, ends with ESC[0m) so the diff engine can repaint any row without
ANSI state carry-over between rows.

Supported blocks:
  # ## ###   headings
  ```lang     fenced code blocks
  - * +       unordered list items
  N.          ordered list items
  >           blockquotes
  ---         horizontal rules
  (blank)     blank separator rows
  (other)     paragraph text

Supported inline spans:
  **bold**   *italic*   `code`   ~~strikethrough~~
"""

import from .terminal { ansi_sgr, term_spaces, term_dashes }
import from .width { visible_width, ansi_pad }
import from .terminal_image { term_hyperlink }

# Background matches the TUI chrome (screen.na.jac BG_R/G/B)
glob _BG_R: int = 18,
     _BG_G: int = 18,
     _BG_B: int = 28;

# ── Block detectors ────────────────────────────────────────────────────────────
def _md_is_blank(s: str) -> bool {
    # True if line is empty or contains only whitespace.
    i: int = 0;
    n = len(s);
    while i < n {
        c = s[i];
        if c != " " and c != "\t" and c != "\r" {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def _md_is_fence(s: str) -> bool {
    # True if line starts with ``` (fenced code block marker).
    n = len(s);
    if n < 3 {
        return False;
    }
    return s[0] == "`" and s[1] == "`" and s[2] == "`";
}

def _md_fence_lang(s: str) -> str {
    # Language identifier after ```. Returns "" if absent.
    if len(s) <= 3 {
        return "";
    }
    lang = s[3:];
    i: int = 0;
    nl = len(lang);
    while i < nl and (lang[i] == " " or lang[i] == "\t") {
        i = i + 1;
    }
    return lang[i:];
}

def _md_heading_level(s: str) -> int {
    # Returns 1/2/3 for ATX headings (# / ## / ###), 0 otherwise.
    n = len(s);
    if n < 2 or s[0] != "#" {
        return 0;
    }
    if s[1] == " " {
        return 1;
    }
    if s[1] == "#" {
        if n < 3 {
            return 0;
        }
        if s[2] == " " {
            return 2;
        }
        if s[2] == "#" and n >= 4 and s[3] == " " {
            return 3;
        }
    }
    return 0;
}

def _md_heading_text(s: str, level: int) -> str {
    # Text after the # prefix and space.
    h_skip = level + 1;
    if len(s) <= h_skip {
        return "";
    }
    return s[h_skip:];
}

def _md_is_hr(s: str) -> bool {
    # Three or more of the same char (- _ *) with optional spaces — no other chars.
    n = len(s);
    if n < 3 {
        return False;
    }
    c = s[0];
    if c != "-" and c != "_" and c != "*" {
        return False;
    }
    count: int = 0;
    i: int = 0;
    while i < n {
        ch = s[i];
        if ch == c {
            count = count + 1;
        } else {
            if ch != " " {
                return False;
            }
        }
        i = i + 1;
    }
    return count >= 3;
}

def _md_is_ul(s: str) -> bool {
    # Unordered list item: starts with "- ", "* ", or "+ ".
    n = len(s);
    if n < 2 {
        return False;
    }
    c = s[0];
    return (c == "-" or c == "*" or c == "+") and s[1] == " ";
}

def _md_is_ol(s: str) -> bool {
    # Ordered list item: one or more digits followed by ". ".
    n = len(s);
    if n < 3 {
        return False;
    }
    i: int = 0;
    while i < n and s[i] >= "0" and s[i] <= "9" {
        i = i + 1;
    }
    if i == 0 or i + 1 >= n {
        return False;
    }
    return s[i] == "." and s[i + 1] == " ";
}

def _md_ol_marker_end(s: str) -> int {
    # Index of the first content char after "N. ".
    n = len(s);
    i: int = 0;
    while i < n and s[i] >= "0" and s[i] <= "9" {
        i = i + 1;
    }
    return i + 2;
}

def _md_is_bq(s: str) -> bool {
    return len(s) >= 1 and s[0] == ">";
}

def _md_bq_text(s: str) -> str {
    if len(s) <= 1 {
        return "";
    }
    if s[1] == " " {
        return s[2:];
    }
    return s[1:];
}

# ── Inline span scanner ────────────────────────────────────────────────────────
def _md_find_close(s: str, start: int, delim: str, dlen: int) -> int {
    # First index >= start where s[i:i+dlen] == delim.  Returns -1 if not found.
    n = len(s);
    i: int = start;
    while i + dlen <= n {
        if s[i:i + dlen] == delim {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

def _md_apply_inline(s: str, base_sgr: str) -> str {
    # Apply inline markdown spans.  Normal text inherits whatever SGR the caller set.
    # After each closing span emits ESC[0m + base_sgr to restore context.
    result: str = "";
    i: int = 0;
    n = len(s);
    while i < n {
        c = s[i];

        # Inline code: `...`  — no inner formatting, yellow tint
        if c == "`" {
            j = _md_find_close(s, i + 1, "`", 1);
            if j >= 0 {
                result = result + "\033[33m" + s[i + 1:j] + "\033[0m" + base_sgr;
                i = j + 1;
                continue;
            }
        }

        # Bold: **...**  — checked before single-star italic
        if c == "*" and i + 1 < n and s[i + 1] == "*" {
            j = _md_find_close(s, i + 2, "**", 2);
            if j >= 0 {
                result = result + "\033[1m" + s[i + 2:j] + "\033[0m" + base_sgr;
                i = j + 2;
                continue;
            }
        }

        # Italic: *...*  (single star not followed by another *)
        if c == "*" and (i + 1 >= n or s[i + 1] != "*") {
            j = _md_find_close(s, i + 1, "*", 1);
            if j > i + 1 {
                result = result + "\033[3m" + s[i + 1:j] + "\033[0m" + base_sgr;
                i = j + 1;
                continue;
            }
        }

        # Strikethrough: ~~...~~
        if c == "~" and i + 1 < n and s[i + 1] == "~" {
            j = _md_find_close(s, i + 2, "~~", 2);
            if j >= 0 {
                result = result + "\033[9m" + s[i + 2:j] + "\033[0m" + base_sgr;
                i = j + 2;
                continue;
            }
        }

        # Inline link: [text](url) — OSC-8 hyperlink or "text (url)" fallback
        if c == "[" {
            j = _md_find_close(s, i + 1, "]", 1);
            if j > i {
                if j + 1 < n {
                    if s[j + 1] == "(" {
                        k = _md_find_close(s, j + 2, ")", 1);
                        if k > j + 1 {
                            link_text = s[i + 1:j];
                            link_url = s[j + 2:k];
                            result = result + term_hyperlink(link_text, link_url);
                            i = k + 1;
                            continue;
                        }
                    }
                }
            }
        }

        result = result + s[i];
        i = i + 1;
    }
    return result;
}

# ── Word wrap ──────────────────────────────────────────────────────────────────
def _md_wrap(styled: str, width: int, base_sgr: str) -> list[str] {
    # Word-wrap `styled` (may contain ANSI codes) to `width` visible columns.
    # Each output row starts with base_sgr, is padded to width, and ends with ESC[0m.
    result: list[str] = [];
    words = styled.split(" ");
    current: str = "";
    current_w: int = 0;
    i: int = 0;
    nw = len(words);

    while i < nw {
        word = words[i];
        ww = visible_width(word);

        if current_w == 0 {
            current = word;
            current_w = ww;
        } else {
            if current_w + 1 + ww <= width {
                current = current + " " + word;
                current_w = current_w + 1 + ww;
            } else {
                result.append(base_sgr + ansi_pad(current, width) + "\033[0m");
                current = word;
                current_w = ww;
            }
        }
        i = i + 1;
    }

    if current_w > 0 or len(result) == 0 {
        result.append(base_sgr + ansi_pad(current, width) + "\033[0m");
    }

    return result;
}

def _md_append(src: list[str], dst: list[str]) {
    # Append all rows from src into dst.
    i: int = 0;
    n = len(src);
    while i < n {
        dst.append(src[i]);
        i = i + 1;
    }
}

# ── Public entry ───────────────────────────────────────────────────────────────
def md_render(text: str, width: int, r: int, g: int, b: int, attrs: int) -> list[str] {
    # Render markdown text into ANSI-styled rows of exactly `width` visible columns.
    # r/g/b: base text colour; attrs bitmask: bold=1, dim=2, italic=4.
    base_sgr = ansi_sgr(r, g, b, _BG_R, _BG_G, _BG_B, attrs);
    result: list[str] = [];

    # Per-element SGR codes (computed inside function body, not at glob-init)
    h1_sgr = ansi_sgr(255, 215, 100, _BG_R, _BG_G, _BG_B, 1);  # bold warm gold
    h2_sgr = ansi_sgr(130, 200, 255, _BG_R, _BG_G, _BG_B, 1);  # bold sky blue
    h3_sgr = ansi_sgr(150, 220, 180, _BG_R, _BG_G, _BG_B, 1);  # bold sage green
    code_line_sgr = ansi_sgr(
        190, 190, 210, 28, 28, 45, 0
    );  # code body: light text, elevated bg
    code_fence_sgr = ansi_sgr(
        100, 100, 140, _BG_R, _BG_G, _BG_B, 2
    );  # dim ``` delimiters
    bq_text_sgr = ansi_sgr(
        170, 190, 210, _BG_R, _BG_G, _BG_B, 4
    );  # italic blockquote text
    bq_bar_sgr = ansi_sgr(80, 120, 160, _BG_R, _BG_G, _BG_B, 0);  # blockquote │ bar
    hr_sgr = ansi_sgr(70, 70, 100, _BG_R, _BG_G, _BG_B, 2);  # dim horizontal rule

    lines = text.split("\n");
    in_fence: bool = False;
    i: int = 0;
    nlines = len(lines);

    while i < nlines {
        line = lines[i];

        # Strip trailing carriage return (CRLF input)
        ll = len(line);
        if ll > 0 and line[ll - 1] == "\r" {
            line = line[:ll - 1];
        }

        # ── Inside a fenced code block ─────────────────────────────────────────
        if in_fence {
            if _md_is_fence(line) {
                close_row = code_fence_sgr + "```";
                result.append(ansi_pad(close_row, width) + "\033[0m");
                in_fence = False;
            } else {
                code_row = code_line_sgr + "  " + line;
                result.append(ansi_pad(code_row, width) + "\033[0m");
            }
            i = i + 1;
            continue;
        }

        # ── Block detection (checked in priority order) ────────────────────────
        if _md_is_blank(line) {
            result.append(base_sgr + ansi_pad("", width) + "\033[0m");
            i = i + 1;
            continue;
        }

        if _md_is_fence(line) {
            lang = _md_fence_lang(line);
            fence_label: str = "```";
            if len(lang) > 0 {
                fence_label = "```" + lang;
            }
            open_row = code_fence_sgr + fence_label;
            result.append(ansi_pad(open_row, width) + "\033[0m");
            in_fence = True;
            i = i + 1;
            continue;
        }

        lvl = _md_heading_level(line);
        if lvl > 0 {
            h_text = _md_heading_text(line, lvl);
            h_sgr = h1_sgr;
            if lvl == 2 {
                h_sgr = h2_sgr;
            }
            if lvl == 3 {
                h_sgr = h3_sgr;
            }
            styled = _md_apply_inline(h_text, h_sgr);
            wrapped = _md_wrap(styled, width, h_sgr);
            _md_append(wrapped, result);
            i = i + 1;
            continue;
        }

        # hr checked before ul/ol so "---" is a rule, not a list item
        if _md_is_hr(line) {
            hr_w = width;
            if hr_w > 80 {
                hr_w = 80;
            }
            hr_content = hr_sgr + term_dashes(hr_w);
            result.append(ansi_pad(hr_content, width) + "\033[0m");
            i = i + 1;
            continue;
        }

        if _md_is_ul(line) {
            item_text = line[2:];
            styled = _md_apply_inline(item_text, base_sgr);
            avail = width - 2;
            if avail < 1 {
                avail = 1;
            }
            wrapped = _md_wrap(styled, avail, base_sgr);
            nw = len(wrapped);
            j: int = 0;
            while j < nw {
                if j == 0 {
                    row = base_sgr + "• " + wrapped[j];
                } else {
                    row = base_sgr + "  " + wrapped[j];
                }
                result.append(row);
                j = j + 1;
            }
            i = i + 1;
            continue;
        }

        if _md_is_ol(line) {
            mend = _md_ol_marker_end(line);
            marker = line[:mend];
            item_text = line[mend:];
            styled = _md_apply_inline(item_text, base_sgr);
            marker_w = len(marker);
            avail = width - marker_w;
            if avail < 1 {
                avail = 1;
            }
            cont_pad = term_spaces(marker_w);
            wrapped = _md_wrap(styled, avail, base_sgr);
            nw = len(wrapped);
            j: int = 0;
            while j < nw {
                if j == 0 {
                    row = base_sgr + marker + wrapped[j];
                } else {
                    row = base_sgr + cont_pad + wrapped[j];
                }
                result.append(row);
                j = j + 1;
            }
            i = i + 1;
            continue;
        }

        if _md_is_bq(line) {
            bq_text = _md_bq_text(line);
            styled = _md_apply_inline(bq_text, bq_text_sgr);
            avail = width - 2;
            if avail < 1 {
                avail = 1;
            }
            wrapped = _md_wrap(styled, avail, bq_text_sgr);
            nw = len(wrapped);
            j: int = 0;
            while j < nw {
                row = bq_bar_sgr + "│ " + wrapped[j];
                result.append(row);
                j = j + 1;
            }
            i = i + 1;
            continue;
        }

        # Paragraph: inline-format and word-wrap
        styled = _md_apply_inline(line, base_sgr);
        wrapped = _md_wrap(styled, width, base_sgr);
        _md_append(wrapped, result);

        i = i + 1;
    }

    return result;
}
