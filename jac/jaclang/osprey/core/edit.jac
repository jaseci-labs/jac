def apply_edit(source: str, old_text: str, new_text: str) -> str;

def apply_multi_edit(source: str, edits: list[list[str]]) -> str;

def replace_lines(
    source: str, start_line: int, end_line: int, replacement: str
) -> str;

def count_matches(source: str, needle: str) -> int;

def compute_unified_diff(old_text: str, new_text: str, context: int = 3) -> str;

def _fmt_range(start: int, length: int) -> str;

def guess_indentation(source: str) -> str;

impl apply_edit(source: str, old_text: str, new_text: str) -> str {
    if len(old_text) == 0 {
        return "ERROR: old_text is empty";
    }
    first = source.find(old_text);
    if first == -1 {
        return "ERROR: old_text not found in file";
    }
    second = source.find(old_text, first + len(old_text));
    if second != -1 {
        return "ERROR: old_text matches more than once; add surrounding context to make it unique";
    }
    return source[:first] + new_text + source[first + len(old_text):];
}

impl apply_multi_edit(source: str, edits: list[list[str]]) -> str {
    work = source;
    for i in range(len(edits)) {
        pair = edits[i];
        old_text: str = pair[0];
        new_text: str = pair[1];
        result = apply_edit(work, old_text, new_text);
        if result.startswith("ERROR:") {
            return "ERROR: multi-edit pair "
                + str(i + 1)
                + " of "
                + str(len(edits))
                + " failed: "
                + result;
        }
        work = result;
    }
    return work;
}

impl replace_lines(
    source: str, start_line: int, end_line: int, replacement: str
) -> str {
    lines = source.split("\n");
    trailing_nl = False;
    if len(lines) > 0 and lines[-1] == "" {
        trailing_nl = True;
        lines = lines[:-1];
    }
    n = len(lines);
    if start_line < 1 or start_line > n {
        return "ERROR: start_line "
            + str(start_line)
            + " out of range (file has "
            + str(n)
            + " lines)";
    }
    if end_line < start_line {
        return "ERROR: end_line "
            + str(end_line)
            + " is before start_line "
            + str(start_line);
    }
    if end_line > n {
        return "ERROR: end_line "
            + str(end_line)
            + " out of range (file has "
            + str(n)
            + " lines)";
    }
    repl_lines = replacement.split("\n");
    if replacement == "" {
        repl_lines = [];
    }
    out_lines = lines[:start_line - 1] + repl_lines + lines[end_line:];
    text = "\n".join(out_lines);
    if len(out_lines) > 0 and trailing_nl {
        text += "\n";
    }
    return text;
}

impl count_matches(source: str, needle: str) -> int {
    if len(needle) == 0 {
        return 0;
    }
    count = 0;
    pos = source.find(needle);
    while pos != -1 {
        count += 1;
        pos = source.find(needle, pos + len(needle));
    }
    return count;
}

impl compute_unified_diff(old_text: str, new_text: str, context: int = 3) -> str {
    if context < 0 {
        return "ERROR: context must be >= 0";
    }
    old_lines = old_text.split("\n");
    if len(old_lines) > 0 and old_lines[-1] == "" {
        old_lines = old_lines[:-1];
    }
    new_lines = new_text.split("\n");
    if len(new_lines) > 0 and new_lines[-1] == "" {
        new_lines = new_lines[:-1];
    }
    n = len(old_lines);
    m = len(new_lines);

    lcs: list[list[int]] = [];
    for i in range(n + 1) {
        row: list[int] = [];
        for j in range(m + 1) {
            row.append(0);
        }
        lcs.append(row);
    }
    for i in range(n - 1, -1, -1) {
        for j in range(m - 1, -1, -1) {
            if old_lines[i] == new_lines[j] {
                lcs[i][j] = lcs[i + 1][j + 1] + 1;
            } elif lcs[i + 1][j] >= lcs[i][j + 1] {
                lcs[i][j] = lcs[i + 1][j];
            } else {
                lcs[i][j] = lcs[i][j + 1];
            }
        }
    }

    tags: list[str] = [];
    old_idx: list[int] = [];
    new_idx: list[int] = [];
    oi = 0;
    oj = 0;
    while oi < n and oj < m {
        if old_lines[oi] == new_lines[oj] {
            tags.append("e");
            old_idx.append(oi);
            new_idx.append(oj);
            oi += 1;
            oj += 1;
        } elif lcs[oi + 1][oj] >= lcs[oi][oj + 1] {
            tags.append("d");
            old_idx.append(oi);
            new_idx.append(oj);
            oi += 1;
        } else {
            tags.append("a");
            old_idx.append(oi);
            new_idx.append(oj);
            oj += 1;
        }
    }
    while oi < n {
        tags.append("d");
        old_idx.append(oi);
        new_idx.append(oj);
        oi += 1;
    }
    while oj < m {
        tags.append("a");
        old_idx.append(oi);
        new_idx.append(oj);
        oj += 1;
    }

    K = len(tags);
    out: list[str] = [];
    k = 0;
    while k < K and tags[k] == "e" {
        k += 1;
    }
    while k < K {
        ws = k - context;
        if ws < 0 {
            ws = 0;
        }
        le = k;
        j = k;
        while j < K {
            if tags[j] != "e" {
                le = j;
                j += 1;
                continue;
            }
            r = j;
            while r < K and tags[r] == "e" {
                r += 1;
            }
            if r < K and (r - j) <= 2 * context {
                j = r;
                continue;
            }
            break;
        }
        we = le + 1 + context;
        if we > K {
            we = K;
        }

        first_old = -1;
        last_old = -1;
        first_new = -1;
        last_new = -1;
        old_len = 0;
        new_len = 0;
        for t in range(ws, we) {
            if tags[t] != "a" {
                old_len += 1;
                if first_old == -1 {
                    first_old = old_idx[t];
                }
                last_old = old_idx[t];
            }
            if tags[t] != "d" {
                new_len += 1;
                if first_new == -1 {
                    first_new = new_idx[t];
                }
                last_new = new_idx[t];
            }
        }
        old_start = first_old + 1;
        if old_len == 0 {
            old_start -= 1;
        }
        new_start = first_new + 1;
        if new_len == 0 {
            new_start -= 1;
        }
        out.append(
            "@@ -"
                + _fmt_range(old_start, old_len)
                + " +"
                + _fmt_range(new_start, new_len)
                + " @@"
        );
        for t in range(ws, we) {
            if tags[t] == "e" {
                out.append(" " + old_lines[old_idx[t]]);
            } elif tags[t] == "d" {
                out.append("-" + old_lines[old_idx[t]]);
            } else {
                out.append("+" + new_lines[new_idx[t]]);
            }
        }

        k = we;
        while k < K and tags[k] == "e" {
            k += 1;
        }
    }
    return "\n".join(out);
}

impl _fmt_range(start: int, length: int) -> str {
    if length == 1 {
        return str(start);
    }
    if length == 0 {
        return str(start - 1) + ",0";
    }
    return str(start) + "," + str(length);
}

impl guess_indentation(source: str) -> str {
    tab_lines = 0;
    widths = [];
    for line in source.splitlines() {
        stripped = line.lstrip(" \t");
        lead = line[:len(line) - len(stripped)];
        if len(stripped) == 0 or len(lead) == 0 {
            continue;
        }
        if lead[0] == "\t" {
            tab_lines += 1;
        } else {
            widths.append(len(lead));
        }
    }
    if len(widths) == 0 {
        if tab_lines > 0 {
            return "\t";
        }
        return "";
    }
    if tab_lines > len(widths) {
        return "\t";
    }
    unit = widths[0];
    for w in widths[1:] {
        a = unit;
        b = w;
        while b != 0 {
            tmp = a % b;
            a = b;
            b = tmp;
        }
        unit = a;
    }
    if unit == 0 {
        unit = 4;
    }
    return " " * unit;
}
