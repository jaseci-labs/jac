import from "@jac/runtime" { Link }

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowRight01Icon,
    ArrowLeft01Icon,
    Link01Icon,
    HierarchyIcon,
    CheckmarkCircle01Icon,
    Alert01Icon
}

glob _ICON_MAP: dict[str, any] = {
         "octicons-arrow-right-24": ArrowRight01Icon,
         "octicons-arrow-left-24": ArrowLeft01Icon,
         "octicons-check-16": CheckmarkCircle01Icon,
         "octicons-alert-16": Alert01Icon,
         "material-vector-link": Link01Icon,
         "material-graph-outline": HierarchyIcon,
         "material-check": CheckmarkCircle01Icon,

     },
     _ADMON_STYLES: dict[str, any] = {
         "note": ["border-sky-500/50", "bg-sky-500/5", "text-sky-400"],
         "info": ["border-sky-500/50", "bg-sky-500/5", "text-sky-400"],
         "abstract": ["border-sky-500/50", "bg-sky-500/5", "text-sky-400"],
         "tip": ["border-emerald-500/50", "bg-emerald-500/5", "text-emerald-400"],
         "success": ["border-emerald-500/50", "bg-emerald-500/5", "text-emerald-400"],
         "example": ["border-violet-500/50", "bg-violet-500/5", "text-violet-400"],
         "warning": ["border-amber-500/50", "bg-amber-500/5", "text-amber-400"],
         "caution": ["border-amber-500/50", "bg-amber-500/5", "text-amber-400"],
         "danger": ["border-red-500/50", "bg-red-500/5", "text-red-400"],
         "bug": ["border-red-500/50", "bg-red-500/5", "text-red-400"],
         "quote": ["border-border", "bg-muted/30", "text-muted-foreground"],

     };

def _is_alnum(c: str) -> bool;

def _count_hashes(s: str) -> int;

def _leading_spaces(s: str) -> int;

def _is_list_line(s: str) -> bool;

def _is_table_sep(s: str) -> bool;

def _split_row(s: str) -> list[str];

def _parse_blocks(
    lines: list[str], anchors: list[str] | None = None
) -> list[dict[str, any]];

def _icon_name_ok(name: str) -> bool;

def _external_href(href: str) -> bool;

def _parse_inline(t: str) -> list[dict[str, any]];

def:pub MDLabel(text: str) -> JsxElement;

def:pub MDSpans(text: str) -> JsxElement;

def:pub MDBlocks(blocks: list[dict[str, any]]) -> JsxElement;

def:pub Markdown(
    lines: list[str], skip_title: str = "", anchors: list[str] | None = None
) -> JsxElement;

impl _is_alnum(c: str) -> bool {
    return ("a" <= c and c <= "z") or ("0" <= c and c <= "9");
}

impl _count_hashes(s: str) -> int {
    k = 0;
    while k < len(s) and s[k] == "#" {
        k = k + 1;
    }
    return k;
}

impl _leading_spaces(s: str) -> int {
    k = 0;
    while k < len(s) and s[k] == " " {
        k = k + 1;
    }
    return k;
}

impl _is_list_line(s: str) -> bool {
    t = s.lstrip();
    if t.startswith("- ") or t.startswith("* ") or t.startswith("+ ") {
        return True;
    }
    k = 0;
    while k < len(t) and "0" <= t[k] and t[k] <= "9" {
        k = k + 1;
    }
    return k > 0 and k + 1 < len(t) and t[k] == "." and t[k + 1] == " ";
}

impl _is_table_sep(s: str) -> bool {
    t = s.strip();
    if not t.startswith("|") or "-" not in t {
        return False;
    }
    for ch in t {
        if ch != "|" and ch != "-" and ch != ":" and ch != " " {
            return False;
        }
    }
    return True;
}

impl _split_row(s: str) -> list[str] {
    t = s.strip();
    if t.startswith("|") {
        t = t[1:];
    }
    if t.endswith("|") {
        t = t[:-1];
    }
    return [c.strip() for c in t.split("|")];
}

impl _parse_blocks(
    lines: list[str], anchors: list[str] | None = None
) -> list[dict[str, any]] {
    blocks: list[dict[str, any]] = [];
    seen_headings = 0;
    i = 0;
    n = len(lines);
    while i < n {
        ln = lines[i];
        s = ln.strip();
        if s == "" {
            i = i + 1;
            continue;
        }
        if s.startswith("```") {
            lang = s[3:].strip();
            body: list[str] = [];
            i = i + 1;
            while i < n and not lines[i].strip().startswith("```") {
                body.append(lines[i]);
                i = i + 1;
            }
            i = i + 1;
            blocks.append({"k": "code", "lang": lang, "lines": body});
            continue;
        }
        if s.startswith("!!! ") or s.startswith("??? ") or s.startswith("???+ ") {
            collapse = s.startswith("???");
            open_flag = s.startswith("???+");
            rest = (s[5:] if open_flag else s[4:]).strip();
            kind = rest.split(" ")[0].lower().strip('"');
            title = kind[0].upper() + kind[1:] if kind else "Note";
            if '"' in rest {
                q1 = rest.index('"');
                inner = rest[q1 + 1:];
                if '"' in inner {
                    title = inner[:inner.index('"')];
                }
            }
            body: list[str] = [];
            i = i + 1;
            while i < n and (lines[i].strip() == "" or lines[i].startswith("    ")) {
                body.append(lines[i][4:] if lines[i].startswith("    ") else "");
                i = i + 1;
            }
            blocks.append(
                {
                    "k": "admon",
                    "kind": kind,
                    "title": title,
                    "collapse": collapse,
                    "open": open_flag,
                    "blocks": _parse_blocks(body),

                }
            );
            continue;
        }
        if s.startswith('=== "') {
            tabs: list[dict[str, any]] = [];
            while i < n and lines[i].strip().startswith('=== "') {
                tt = lines[i].strip()[4:].strip().strip('"');
                i = i + 1;
                tbody: list[str] = [];
                while i < n
                    and (lines[i].strip() == "" or lines[i].startswith("    ")) {
                    tbody.append(lines[i][4:] if lines[i].startswith("    ") else "");
                    i = i + 1;
                }
                tabs.append({"title": tt, "blocks": _parse_blocks(tbody)});
            }
            blocks.append({"k": "tabs", "items": tabs});
            continue;
        }
        if s.startswith("#") {
            level = _count_hashes(s);
            if level <= 6 and level < len(s) and s[level] == " " {
                text = s[level + 1:].strip();
                attr_at = text.rfind(" {#");
                if attr_at >= 0 and text.endswith("}") {
                    text = text[:attr_at].rstrip();
                }
                anchor = "";
                if level == 2 or level == 3 {
                    if anchors is not None and seen_headings < len(anchors) {
                        anchor = anchors[seen_headings];
                    }
                    seen_headings = seen_headings + 1;
                }
                blocks.append({"k": "h", "level": level, "text": text, "id": anchor});
                i = i + 1;
                continue;
            }
        }
        if s == "---" or s == "***" or s == "___" {
            blocks.append({"k": "hr"});
            i = i + 1;
            continue;
        }
        if s.startswith("|") and i + 1 < n and _is_table_sep(lines[i + 1]) {
            header = _split_row(s);
            i = i + 2;
            rows: list[list[str]] = [];
            while i < n and lines[i].strip().startswith("|") {
                rows.append(_split_row(lines[i]));
                i = i + 1;
            }
            blocks.append({"k": "table", "header": header, "rows": rows});
            continue;
        }
        if _is_list_line(ln) {
            items: list[dict[str, any]] = [];
            while i < n
                and (
                    _is_list_line(lines[i])
                    or (
                        lines[i].strip() != ""
                        and _leading_spaces(lines[i]) >= 2
                        and not lines[i].strip().startswith("```")
                    )
                ) {
                cur = lines[i];
                if _is_list_line(cur) {
                    indent = _leading_spaces(cur);
                    t = cur.lstrip();
                    ordered = False;
                    if t.startswith("- ") or t.startswith("* ") or t.startswith("+ ") {
                        t = t[2:];
                    } else {
                        dot = t.index(".");
                        ordered = True;
                        t = t[dot + 2:];
                    }
                    items.append(
                        {"depth": indent // 2, "ordered": ordered, "text": t.strip()}
                    );
                } elif len(items) > 0 {
                    last = items[len(items) - 1];
                    last["text"] = (last["text"] as str) + " " + lines[i].strip();
                }
                i = i + 1;
            }
            blocks.append({"k": "list", "items": items});
            continue;
        }
        if s.startswith(">") {
            body: list[str] = [];
            while i < n and lines[i].strip().startswith(">") {
                t = lines[i].strip()[1:];
                body.append(t[1:] if t.startswith(" ") else t);
                i = i + 1;
            }
            blocks.append({"k": "quote", "blocks": _parse_blocks(body)});
            continue;
        }
        if s.startswith("<") {
            body: list[str] = [];
            while i < n and lines[i].strip() != "" {
                body.append(lines[i]);
                i = i + 1;
            }
            blocks.append({"k": "html", "text": "  ".join(body)});
            continue;
        }
        para: list[str] = [];
        while i < n {
            t = lines[i].strip();
            if t == ""
                or t.startswith("```")
                or t.startswith("#")
                or t.startswith(">")
                or t.startswith("!!! ")
                or t.startswith("??? ")
                or t.startswith("???+ ")
                or t.startswith('=== "')
                or _is_list_line(lines[i])
                or (t.startswith("|") and i + 1 < n and _is_table_sep(lines[i + 1])) {
                break;
            }
            para.append(t);
            i = i + 1;
        }
        blocks.append({"k": "p", "text": " ".join(para)});
    }
    return blocks;
}

impl _icon_name_ok(name: str) -> bool {
    if not (
        name.startswith("octicons-")
        or name.startswith("material-")
        or name.startswith("fontawesome-")
        or name.startswith("simple-")
    ) {
        return False;
    }
    for ch in name {
        if not (_is_alnum(ch) or ch == "-") {
            return False;
        }
    }
    return True;
}

impl _external_href(href: str) -> bool {
    s = href.strip().lower();
    for scheme in ("http:", "https:", "mailto:") {
        if s.startswith(scheme) {
            return True;
        }
    }
    return ":" not in s;
}

impl _parse_inline(t: str) -> list[dict[str, any]] {
    spans: list[dict[str, any]] = [];
    buf = "";
    i = 0;
    n = len(t);
    while i < n {
        c = t[i];
        if c == ":" {
            close = t.find(":", i + 1);
            if close > i + 1 and _icon_name_ok(t[i + 1:close]) {
                if buf != "" {
                    spans.append({"k": "t", "t": buf});
                    buf = "";
                }
                spans.append({"k": "icon", "name": t[i + 1:close]});
                i = close + 1;

                if i < n and t[i] == "{" {
                    brace = t.find("}", i);
                    if brace > i and "." in t[i:brace] {
                        i = brace + 1;
                    }
                }
                continue;
            }
        }
        if c == "`" {
            close = t.find("`", i + 1);
            if close > i {
                if buf != "" {
                    spans.append({"k": "t", "t": buf});
                    buf = "";
                }
                spans.append({"k": "code", "t": t[i + 1:close]});
                i = close + 1;
                continue;
            }
        }
        if c == "*" and i + 1 < n and t[i + 1] == "*" {
            close = t.find("**", i + 2);
            if close > i {
                if buf != "" {
                    spans.append({"k": "t", "t": buf});
                    buf = "";
                }
                spans.append({"k": "strong", "t": t[i + 2:close]});
                i = close + 2;
                continue;
            }
        }
        if c == "*" {
            close = t.find("*", i + 1);
            if close > i {
                if buf != "" {
                    spans.append({"k": "t", "t": buf});
                    buf = "";
                }
                spans.append({"k": "em", "t": t[i + 1:close]});
                i = close + 1;
                continue;
            }
        }
        if c == "!" and i + 1 < n and t[i + 1] == "[" {
            lb_end = t.find("](", i + 2);
            if lb_end > i {
                pe = t.find(")", lb_end + 2);
                if pe > lb_end {
                    if buf != "" {
                        spans.append({"k": "t", "t": buf});
                        buf = "";
                    }
                    spans.append(
                        {"k": "img", "alt": t[i + 2:lb_end], "src": t[lb_end + 2:pe]}
                    );
                    i = pe + 1;
                    continue;
                }
            }
        }
        if c == "[" {
            lb_end = t.find("](", i + 1);
            if lb_end > i {
                pe = t.find(")", lb_end + 2);
                if pe > lb_end {
                    if buf != "" {
                        spans.append({"k": "t", "t": buf});
                        buf = "";
                    }
                    spans.append(
                        {"k": "link", "t": t[i + 1:lb_end], "href": t[lb_end + 2:pe]}
                    );
                    i = pe + 1;
                    continue;
                }
            }
        }
        buf = buf + c;
        i = i + 1;
    }
    if buf != "" {
        spans.append({"k": "t", "t": buf});
    }
    return spans;
}
