impl MDLabel(text: str) -> JsxElement {
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

impl MDSpans(text: str) -> JsxElement {
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
                        <MDSpans text={sp["t"] as str}/>
                    </strong>
                } elif sp["k"] == "em" {
                    <em key={str(i)}>
                        <MDSpans text={sp["t"] as str}/>
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
                    } elif _external_href(sp["href"] as str) {
                        <a
                            key={str(i)}
                            href={sp["href"]}
                            target="_blank"
                            rel="noreferrer"
                            className="font-medium text-primary hover:underline"
                        >
                            <MDLabel text={sp["t"] as str}/>
                        </a>
                    } else {
                        <span key={str(i)}>
                            <MDLabel text={sp["t"] as str}/>
                        </span>
                    }
                } else {
                    <span key={str(i)}>{sp["t"]}</span>
                }
            }}
        </span>;
}

impl MDBlocks(blocks: list[dict[str, any]]) -> JsxElement {
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
                        {for (ii, it) in enumerate(
                            b["items"] as list[dict[str, any]]
                        ) {
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
                                <MDBlocks blocks={b["blocks"] as list[dict[str, any]]}/>
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
                            <MDBlocks blocks={b["blocks"] as list[dict[str, any]]}/>
                        </div>
                    }
                } elif b["k"] == "tabs" {
                    <Tabs key={str(bi)} defaultValue="t0" className="my-5">
                        <TabsList className="mb-1 flex-wrap">
                            {for (ti, tb) in enumerate(
                                b["items"] as list[dict[str, any]]
                            ) {
                                <TabsTrigger key={str(ti)} value={"t" + str(ti)}>
                                    <MDLabel text={tb["title"] as str}/>
                                </TabsTrigger>
                            }}
                        </TabsList>
                        {for (ti, tb) in enumerate(
                            b["items"] as list[dict[str, any]]
                        ) {
                            <TabsContent key={str(ti)} value={"t" + str(ti)}>
                                <MDBlocks
                                    blocks={tb["blocks"] as list[dict[str, any]]}
                                />
                            </TabsContent>
                        }}
                    </Tabs>
                } elif b["k"] == "quote" {
                    <div
                        key={str(bi)}
                        className="my-4 border-l-2 border-border pl-4 text-muted-foreground"
                    >
                        <MDBlocks blocks={b["blocks"] as list[dict[str, any]]}/>
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

impl Markdown(
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
