import from "@jac/runtime" { Link }
import from core.site.ui.CodeBlock { CodeLines }
import from .MermaidDiagram { MermaidDiagram }
import from core.site.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowRight01Icon,
    ArrowLeft01Icon,
    Link01Icon,
    HierarchyIcon,
    CheckmarkCircle01Icon,
    Alert01Icon
}

glob _ICON_MAP: dict = {
         "octicons-arrow-right-24": ArrowRight01Icon,
         "octicons-arrow-left-24": ArrowLeft01Icon,
         "octicons-check-16": CheckmarkCircle01Icon,
         "octicons-alert-16": Alert01Icon,
         "material-vector-link": Link01Icon,
         "material-graph-outline": HierarchyIcon,
         "material-check": CheckmarkCircle01Icon,

     },
     _ADMON_STYLES: dict = {
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

def _is_alnum(c: str) -> bool {
    return ("a" <= c and c <= "z") or ("0" <= c and c <= "9");
}

def _count_hashes(s: str) -> int {
    k = 0;
    while k < len(s) and s[k] == "#" {
        k = k + 1;
    }
    return k;
}

def _leading_spaces(s: str) -> int {
    k = 0;
    while k < len(s) and s[k] == " " {
        k = k + 1;
    }
    return k;
}

def _is_list_line(s: str) -> bool {
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

def _is_table_sep(s: str) -> bool {
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

def _split_row(s: str) -> list[str] {
    t = s.strip();
    if t.startswith("|") {
        t = t[1:];
    }
    if t.endswith("|") {
        t = t[:-1];
    }
    return [c.strip() for c in t.split("|")];
}

def _parse_blocks(lines: list[str], anchors: list[str] | None = None) -> list[dict] {
    blocks: list[dict] = [];
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
            tabs: list[dict] = [];
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
            items: list[dict] = [];
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

def _icon_name_ok(name: str) -> bool {
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

def _parse_inline(t: str) -> list[dict] {
    spans: list[dict] = [];
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

def:pub MDLabel(text: str) -> JsxElement {
    return
        <span>
            {for (i, seg) in enumerate(text.split("`")) {
                if i % 2 == 1 {
                    <code
                        key={str(i)}
                        className="rounded bg-muted pl-1 pr-1 font-mono text-[0.9em]"
                    >
                        {seg}
                    </code>
                } else {
                    <span key={str(i)}>{seg}</span>
                }
            }}
        </span>;
}

def:pub MDSpans(text: str) -> JsxElement {
    return
        <span>
            {for (i, sp) in enumerate(_parse_inline(text)) {
                if sp["k"] == "code" {
                    <code
                        key={str(i)}
                        className="rounded bg-muted pl-1.5 pr-1.5 pt-0.5 pb-0.5 font-mono text-[13px] text-foreground"
                    >
                        {sp["t"]}
                    </code>
                } elif sp["k"] == "strong" {
                    <strong key={str(i)} className="font-semibold text-foreground">
                        <MDLabel text={sp["t"] as str}/>
                    </strong>
                } elif sp["k"] == "em" {
                    <em key={str(i)}>
                        <MDLabel text={sp["t"] as str}/>
                    </em>
                } elif sp["k"] == "icon" {
                    if (sp["name"] as str) in _ICON_MAP {
                        <HugeiconsIcon
                            key={str(i)}
                            icon={_ICON_MAP[sp["name"]]}
                            strokeWidth={2}
                            className="inline size-4 align-[-3px] text-primary"
                        />
                    } else {
                        <span key={str(i)}></span>
                    }
                } elif sp["k"] == "img" {
                    <img
                        key={str(i)}
                        src={sp["src"]}
                        alt={sp["alt"]}
                        className="my-2 inline-block max-w-full rounded-lg border border-border/60"
                    />
                } elif sp["k"] == "link" {
                    if (sp["href"] as str).startswith("/") {
                        <Link
                            key={str(i)}
                            to={sp["href"]}
                            className="font-medium text-primary hover:underline"
                        >
                            <MDLabel text={sp["t"] as str}/>
                        </Link>
                    } elif (sp["href"] as str).startswith("#") {
                        <a
                            key={str(i)}
                            href={sp["href"]}
                            className="font-medium text-primary hover:underline"
                        >
                            <MDLabel text={sp["t"] as str}/>
                        </a>
                    } else {
                        <a
                            key={str(i)}
                            href={sp["href"]}
                            target="_blank"
                            rel="noreferrer"
                            className="font-medium text-primary hover:underline"
                        >
                            <MDLabel text={sp["t"] as str}/>
                        </a>
                    }
                } else {
                    <span key={str(i)}>{sp["t"]}</span>
                }
            }}
        </span>;
}

def:pub MDBlocks(blocks: list[dict]) -> JsxElement {
    return
        <div>
            {for (bi, b) in enumerate(blocks) {
                if b["k"] == "h" {
                    if b["level"] == 1 {
                        <h1
                            key={str(bi)}
                            id={b["id"]}
                            className="mt-2 mb-5 scroll-mt-24 text-balance text-3xl font-bold tracking-tight"
                        >
                            <MDLabel text={b["text"] as str}/>
                        </h1>
                    } elif b["level"] == 2 {
                        <h2
                            key={str(bi)}
                            id={b["id"]}
                            className="mt-10 mb-4 scroll-mt-24 border-b border-border/60 pb-2 text-2xl font-semibold tracking-tight"
                        >
                            <MDLabel text={b["text"] as str}/>
                        </h2>
                    } elif b["level"] == 3 {
                        <h3
                            key={str(bi)}
                            id={b["id"]}
                            className="mt-8 mb-3 scroll-mt-24 text-lg font-semibold"
                        >
                            <MDLabel text={b["text"] as str}/>
                        </h3>
                    } else {
                        <h4
                            key={str(bi)}
                            id={b["id"]}
                            className="mt-6 mb-2 scroll-mt-24 text-base font-semibold"
                        >
                            <MDLabel text={b["text"] as str}/>
                        </h4>
                    }
                } elif b["k"] == "p" {
                    <p key={str(bi)} className="mb-4 leading-7 text-foreground/90">
                        <MDSpans text={b["text"] as str}/>
                    </p>
                } elif b["k"] == "code" {
                    if (b["lang"] as str) == "mermaid" {
                        <MermaidDiagram
                            key={str(bi)}
                            code={"\n".join(b["lines"] as list[str])}
                        />
                    } else {
                        <div
                            key={str(bi)}
                            className="code-window my-5 overflow-hidden rounded-lg"
                        >
                            <div
                                className="code-titlebar flex items-center pl-4 pr-4 pt-1.5 pb-1.5"
                            >
                                <span
                                    className="font-mono text-[10px] uppercase tracking-widest text-white/40"
                                >
                                    {b["lang"] or "text"}
                                </span>
                            </div>
                            <div className="overflow-x-auto pt-3 pb-3">
                                <CodeLines
                                    lines={b["lines"] as list[str]}
                                    lang={b["lang"] as str}
                                    numbers={False}
                                />
                            </div>
                        </div>
                    }
                } elif b["k"] == "list" {
                    <div key={str(bi)} className="mb-4 flex flex-col gap-1.5">
                        {for (ii, it) in enumerate(b["items"] as list[dict]) {
                            <div
                                key={str(ii)}
                                className="flex items-start gap-2 leading-7 text-foreground/90"
                                style={{
                                    "paddingLeft": str((it["depth"] as int) * 16) + "px"
                                }}
                            >
                                <span className="select-none pt-0 text-primary">
                                    {"•" if not it["ordered"] else str(ii + 1) + "."}
                                </span>
                                <span className="min-w-0">
                                    <MDSpans text={it["text"] as str}/>
                                </span>
                            </div>
                        }}
                    </div>
                } elif b["k"] == "admon" {
                    if b["collapse"] {
                        <details
                            key={str(bi)}
                            open={b["open"] as bool}
                            className={"md-details my-5 rounded-r-lg border-l-2 "
                                + (
                                    (
                                        (_ADMON_STYLES[b["kind"]] as list[str])[0]
                                        + " "
                                        + (_ADMON_STYLES[b["kind"]] as list[str])[1]
                                    )
                                        if b["kind"] in _ADMON_STYLES
                                        else "border-border bg-muted/30"
                                )}
                        >
                            <summary
                                className={"flex cursor-pointer select-none items-center gap-2 pt-4 pb-4 pl-5 pr-5 text-xs font-semibold uppercase tracking-widest "
                                    + (
                                        (_ADMON_STYLES[b["kind"]] as list[str])[2]
                                            if b["kind"] in _ADMON_STYLES
                                            else "text-muted-foreground"
                                    )}
                            >
                                <span
                                    className="md-chev inline-block transition-transform duration-200"
                                >
                                    ▸
                                </span>
                                <MDLabel text={b["title"] as str}/>
                            </summary>
                            <div className="pl-5 pr-5 pb-4">
                                <MDBlocks blocks={b["blocks"] as list[dict]}/>
                            </div>
                        </details>
                    } else {
                        <div
                            key={str(bi)}
                            className={"my-5 rounded-r-lg border-l-2 pt-4 pb-4 pl-5 pr-5 "
                                + (
                                    (
                                        (_ADMON_STYLES[b["kind"]] as list[str])[0]
                                        + " "
                                        + (_ADMON_STYLES[b["kind"]] as list[str])[1]
                                    )
                                        if b["kind"] in _ADMON_STYLES
                                        else "border-border bg-muted/30"
                                )}
                        >
                            <p
                                className={"mb-2 text-xs font-semibold uppercase tracking-widest "
                                    + (
                                        (_ADMON_STYLES[b["kind"]] as list[str])[2]
                                            if b["kind"] in _ADMON_STYLES
                                            else "text-muted-foreground"
                                    )}
                            >
                                {b["title"]}
                            </p>
                            <MDBlocks blocks={b["blocks"] as list[dict]}/>
                        </div>
                    }
                } elif b["k"] == "tabs" {
                    <Tabs key={str(bi)} defaultValue="t0" className="my-5">
                        <TabsList className="mb-1 flex-wrap">
                            {for (ti, tb) in enumerate(b["items"] as list[dict]) {
                                <TabsTrigger key={str(ti)} value={"t" + str(ti)}>
                                    <MDLabel text={tb["title"] as str}/>
                                </TabsTrigger>
                            }}
                        </TabsList>
                        {for (ti, tb) in enumerate(b["items"] as list[dict]) {
                            <TabsContent key={str(ti)} value={"t" + str(ti)}>
                                <MDBlocks blocks={tb["blocks"] as list[dict]}/>
                            </TabsContent>
                        }}
                    </Tabs>
                } elif b["k"] == "quote" {
                    <div
                        key={str(bi)}
                        className="my-4 border-l-2 border-border pl-4 text-muted-foreground"
                    >
                        <MDBlocks blocks={b["blocks"] as list[dict]}/>
                    </div>
                } elif b["k"] == "table" {
                    <div key={str(bi)} className="my-5 overflow-x-auto">
                        <table className="w-full border-collapse text-sm">
                            <thead>
                                <tr>
                                    {for (hi, h) in enumerate(
                                        b["header"] as list[str]
                                    ) {
                                        <th
                                            key={str(hi)}
                                            className="border-b border-border pt-2 pb-2 pl-3 pr-3 text-left font-semibold"
                                        >
                                            <MDSpans text={h}/>
                                        </th>
                                    }}
                                </tr>
                            </thead>
                            <tbody>
                                {for (ri, row) in enumerate(
                                    b["rows"] as list[list[str]]
                                ) {
                                    <tr key={str(ri)} className="align-top">
                                        {for (ci, cell) in enumerate(row) {
                                            <td
                                                key={str(ci)}
                                                className="border-b border-border/40 pt-2 pb-2 pl-3 pr-3 leading-6 text-foreground/90"
                                            >
                                                <MDSpans text={cell}/>
                                            </td>
                                        }}
                                    </tr>
                                }}
                            </tbody>
                        </table>
                    </div>
                } elif b["k"] == "hr" {
                    <hr key={str(bi)} className="my-8 border-border/60"/>
                } elif b["k"] == "html" {
                    <div key={str(bi)} className="my-5 max-w-full overflow-x-auto">
                        {unsafe_html(b["text"] as str)}
                    </div>
                }
            }}
        </div>;
}

def:pub Markdown(
    lines: list[str], skip_title: str = "", anchors: list[str] | None = None
) -> JsxElement {
    blocks = _parse_blocks(lines, anchors);
    if len(blocks) > 0 and skip_title != "" {
        first = blocks[0];
        if first["k"] == "h"
            and first["level"] == 1
            and (first["text"] as str).strip() == skip_title.strip() {
            blocks = blocks[1:];
        }
    }
    return
        <div className="min-w-0">
            <MDBlocks blocks={blocks}/>
        </div>;
}
