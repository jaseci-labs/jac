impl TierLabel(y: int, text: str, hot: bool = False) -> JsxElement {
    return
        <text
            x="500"
            y={y}
            textAnchor="middle"
            fontSize="11"
            fontWeight="700"
            fontFamily="monospace"
            letterSpacing="2.5"
            fill={"#ff6b35" if hot else "var(--muted-foreground)"}
        >
            {text}
        </text>;
}

impl ConvergeDiagram -> JsxElement {
    return
        <div className="overflow-x-auto">
            <svg
                viewBox="0 0 1000 590"
                className="w-full min-w-[760px]"
                role="img"
                aria-label="Multiple languages and frameworks (Python, TypeScript, C, C++ and Rust, React and React Native) flow into one universal language, Jac, which targets web, mobile, desktop, cloud, microservices, databases and native platforms"
            >
                <TierLabel y={16} text="MULTIPLE LANGUAGES AND FRAMEWORKS"/>
                {for (i, s) in enumerate(_STACKS) {
                    <g key={"s" + str(i)}>
                        <rect
                            x={i * 204}
                            y="32"
                            width="184"
                            height="78"
                            rx="10"
                            fill="var(--card)"
                            fillOpacity="0.6"
                            stroke="var(--border)"
                            strokeDasharray="4 3"
                        />
                        <text
                            x={i * 204 + 16}
                            y="58"
                            fontSize="15"
                            fontWeight="600"
                            fill="var(--foreground)"
                        >
                            {s["name"]}
                        </text>
                        <text
                            x={i * 204 + 16}
                            y="77"
                            fontSize="11"
                            fill="var(--muted-foreground)"
                        >
                            {s["eco"]}
                        </text>
                        <text
                            x={i * 204 + 16}
                            y="96"
                            fontSize="10"
                            fontFamily="monospace"
                            fill="var(--muted-foreground)"
                            fillOpacity="0.85"
                        >
                            {s["tools"]}
                        </text>
                        <ConvPath
                            d={"M"
                                + str(i * 204 + 92)
                                + ",110 C"
                                + str(i * 204 + 92)
                                + ",175 500,170 500,228"}
                            fill="none"
                            stroke="var(--muted-foreground)"
                            strokeOpacity="0.5"
                            strokeWidth="1.3"
                            strokeDasharray="4 4"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={{"once": True, "amount": 0.3}}
                            transition={{"duration": 0.8, "delay": 0.1 + i * 0.08}}
                        />
                    </g>
                }}
                <circle
                    cx="500"
                    cy="290"
                    r="84"
                    fill="#ff6b35"
                    fillOpacity="0.06"
                    className="pulse-ring"
                />
                <polygon
                    points="500,228 554,259 554,321 500,352 446,321 446,259"
                    fill="#ff6b35"
                    stroke="#ff6b35"
                />
                <text
                    x="500"
                    y="292"
                    textAnchor="middle"
                    fontSize="26"
                    fontWeight="700"
                    fontFamily="monospace"
                    fill="#ffffff"
                >
                    jac
                </text>
                <text
                    x="500"
                    y="311"
                    textAnchor="middle"
                    fontSize="9.5"
                    fontFamily="monospace"
                    fill="#ffffff"
                    fillOpacity="0.9"
                >
                    one language
                </text>
                <text
                    x="0"
                    y="282"
                    fontSize="11"
                    fontWeight="700"
                    fontFamily="monospace"
                    letterSpacing="2.5"
                    fill="#ff6b35"
                >
                    ONE UNIVERSAL LANGUAGE
                </text>
                <text x="0" y="304" fontSize="13" fill="var(--foreground)">
                    one syntax · one type checker
                </text>
                <text
                    x="1000"
                    y="282"
                    textAnchor="end"
                    fontSize="11"
                    fontWeight="700"
                    fontFamily="monospace"
                    letterSpacing="2.5"
                    fill="#ff6b35"
                >
                    ONE BINARY
                </text>
                <text
                    x="1000"
                    y="304"
                    textAnchor="end"
                    fontSize="13"
                    fill="var(--foreground)"
                >
                    build anything with nothing else
                </text>
                {for (j, t) in enumerate(_PLATFORMS_OUT) {
                    <g key={"t" + str(j)}>
                        <ConvPath
                            d={"M500,352 C500,410 "
                                + str(j * 144 + 68)
                                + ",405 "
                                + str(j * 144 + 68)
                                + ",470"}
                            fill="none"
                            stroke="#ff6b35"
                            strokeOpacity="0.6"
                            strokeWidth="1.4"
                            initial={{"pathLength": 0}}
                            whileInView={{"pathLength": 1}}
                            viewport={{"once": True, "amount": 0.3}}
                            transition={{"duration": 0.7, "delay": 0.6 + j * 0.07}}
                        />
                        <rect
                            x={j * 144 + 2}
                            y="470"
                            width="132"
                            height="80"
                            rx="10"
                            fill="var(--card)"
                            stroke="#ff6b35"
                            strokeOpacity="0.55"
                        />
                        <text
                            x={j * 144 + 14}
                            y="496"
                            fontSize="14"
                            fontWeight="600"
                            fill="var(--foreground)"
                        >
                            {t["name"]}
                        </text>
                        <text
                            x={j * 144 + 14}
                            y="516"
                            fontSize="10.5"
                            fill="var(--muted-foreground)"
                        >
                            {t["sub1"]}
                        </text>
                        <text
                            x={j * 144 + 14}
                            y="532"
                            fontSize="10.5"
                            fill="var(--muted-foreground)"
                        >
                            {t["sub2"]}
                        </text>
                    </g>
                }}
                <TierLabel y={582} text="TARGETS MANY PLATFORMS"/>
            </svg>
        </div>;
}

impl FileGlyph(name: str, segs: list[dict[str, any]]) -> JsxElement {
    return
        <div className="code-window overflow-hidden rounded-lg">
            <div
                className="code-titlebar px-3 py-1.5 font-mono text-[10px] text-white/60"
            >
                {name}
            </div>
            <div className="flex flex-col gap-1 p-2.5">
                {for (si, seg) in enumerate(segs) {
                    <div
                        key={str(si)}
                        className="flex flex-col gap-[5px] rounded-sm border px-1.5 py-1"
                        style={{
                            "borderColor": (glue_color(seg["kind"]) + "b3")
                                if seg["kind"] != ""
                                else "transparent",
                            "backgroundColor": (glue_color(seg["kind"]) + "29")
                                if seg["kind"] != ""
                                else "transparent"
                        }}
                    >
                        {for (li, w) in enumerate(seg["lines"]) {
                            <span
                                key={str(li)}
                                className="block h-[3px] rounded-full"
                                style={{
                                    "width": str(w) + "%",
                                    "backgroundColor": (glue_color(seg["kind"]) + "cc")
                                        if seg["kind"] != ""
                                        else "rgb(255 255 255 / 0.16)"
                                }}
                            ></span>
                        }}
                    </div>
                }}
            </div>
        </div>;
}

impl GlueChip(kind: str, struck: bool = False) -> JsxElement {
    return
        <span
            className={cn(
                "inline-flex items-center gap-1.5 rounded-md border border-border/80 bg-background/60 px-2 py-1 font-mono text-[11px] text-foreground",
                "strike-chip text-muted-foreground" if struck else ""
            )}
        >
            <span
                className="size-2 shrink-0 rounded-sm"
                style={{"backgroundColor": glue_color(kind)}}
            ></span>
            {glue_label(kind)}
        </span>;
}

impl CompareRow(
    label: str,
    hint: str,
    delta_from: str,
    delta_to: str,
    delta_unit: str,
    left: any = None,
    right: any = None,
    first: bool = False
) -> JsxElement {
    return
        <>
            <div
                className={cn(
                    "lg:col-span-3",
                    "pt-2" if first else "mt-10 border-t border-border/70 pt-6 lg:mt-0"
                )}
            >
                <p
                    className="font-mono text-[11px] uppercase tracking-widest text-foreground"
                >
                    {label}
                </p>
                <p
                    className="mt-1 max-w-xl text-xs leading-relaxed text-muted-foreground"
                >
                    {hint}
                </p>
            </div>
            <div className="min-w-0 pt-4 lg:pb-8">
                <p
                    className="mb-3 font-mono text-[10px] uppercase tracking-widest text-muted-foreground lg:hidden"
                >
                    Conventional stack
                </p>
                {left}
            </div>
            <div className="flex items-center justify-center py-4 lg:py-0">
                <div className="flex flex-row items-center gap-2 lg:flex-col lg:gap-1">
                    <span
                        className="font-mono text-lg font-semibold tabular-nums text-muted-foreground"
                    >
                        {delta_from}
                    </span>
                    <span className="text-primary">→</span>
                    <span
                        className="font-mono text-lg font-semibold tabular-nums text-primary"
                    >
                        {delta_to}
                    </span>
                    <span
                        className="font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
                    >
                        {delta_unit}
                    </span>
                </div>
            </div>
            <div
                className="min-w-0 rounded-xl border border-primary/40 bg-primary/[0.05] p-4 lg:mt-4 lg:mb-8 lg:p-5"
            >
                <p
                    className="mb-3 font-mono text-[10px] uppercase tracking-widest text-primary lg:hidden"
                >
                    With Jac
                </p>
                {right}
            </div>
        </>;
}

impl StackCompare -> JsxElement {
    stack_left = <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-5">
        {for layer in _LAYERS {
            <div
                key={layer["name"]}
                className="rounded-lg border border-dashed border-border bg-background/40 p-2.5"
            >
                <p className="text-xs font-semibold tracking-tight">{layer["name"]}</p>
                <div className="mt-1.5 flex flex-wrap gap-1">
                    {for t in layer["tools"] {
                        <span
                            key={t}
                            className="whitespace-nowrap rounded border border-border/60 px-1 py-px font-mono text-[10px] text-muted-foreground"
                        >
                            {t}
                        </span>
                    }}
                </div>
            </div>
        }}
    </div>;
    stack_right = <div className="flex items-start gap-3">
        <img src="/static/assets/jac-logo.svg" alt="" className="size-8 shrink-0"/>
        <div>
            <p className="text-sm font-semibold tracking-tight">
                The Jac compiler and runtime
            </p>
            <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                One binary that is also the package manager, test runner, formatter and deploy tool.
            </p>
        </div>
    </div>;
    people_left = <div className="grid grid-cols-2 gap-3 xl:grid-cols-4">
        {for r in _ROLES {
            <div key={r["role"]} className="flex min-w-0 flex-col gap-2">
                <div>
                    <p className="text-xs font-semibold tracking-tight">{r["role"]}</p>
                    <p className="font-mono text-[10px] text-muted-foreground">
                        {r["lang"]}
                    </p>
                </div>
                {for f in r["files"] {
                    <FileGlyph key={f["name"]} name={f["name"]} segs={f["segs"]}/>
                }}
                <div className="flex flex-wrap gap-1">
                    {for k in r["kinds"] {
                        <GlueChip key={k} kind={k}/>
                    }}
                </div>
            </div>
        }}
    </div>;
    people_right = <div className="flex flex-col gap-2">
        <div>
            <p className="text-xs font-semibold tracking-tight">
                One engineer, or one agent
            </p>
            <p className="font-mono text-[10px] text-muted-foreground">Jac</p>
        </div>
        <FileGlyph name="main.jac" segs={_JAC_FILE}/>
        <p className="text-xs leading-relaxed text-muted-foreground">
            Frontend, backend, data and deployment in one file, with no glue.
        </p>
    </div>;
    glue_left = <div className="flex flex-wrap gap-1.5">
        {for g in _GLUE_KINDS {
            <GlueChip key={g["key"]} kind={g["key"]}/>
        }}
    </div>;
    glue_right = <div>
        <div className="flex flex-wrap gap-1.5">
            {for g in _GLUE_KINDS {
                <GlueChip key={g["key"]} kind={g["key"]} struck={True}/>
            }}
        </div>
        <p className="mt-3 text-xs leading-relaxed text-muted-foreground">
            The compiler and runtime generate all seven.
        </p>
    </div>;
    return
        <div
            className="grid grid-cols-1 lg:grid-cols-[minmax(0,2fr)_72px_minmax(0,1fr)] lg:gap-x-5"
        >
            <div className="hidden pb-4 lg:block">
                <p
                    className="font-mono text-xs uppercase tracking-[0.2em] text-foreground"
                >
                    A conventional stack
                </p>
                <p className="mt-1 font-mono text-[11px] text-muted-foreground">
                    24 tools · 4 specialists · 7 kinds of glue
                </p>
            </div>
            <div className="hidden lg:block"></div>
            <div className="hidden pb-4 lg:block">
                <p
                    className="font-mono text-xs uppercase tracking-[0.2em] text-primary"
                >
                    The same app in Jac
                </p>
                <p className="mt-1 font-mono text-[11px] text-muted-foreground">
                    1 binary · 1 author · 0 glue
                </p>
            </div>
            <CompareRow
                label="Stack to manage"
                hint="Everything to install, version and keep compatible."
                delta_from="24"
                delta_to="1"
                delta_unit="tools"
                left={stack_left}
                right={stack_right}
                first={True}
            />
            <CompareRow
                label="Who writes it"
                hint="Each specialist's files, with the glue marked in colour."
                delta_from="4"
                delta_to="1"
                delta_unit="authors"
                left={people_left}
                right={people_right}
            />
            <CompareRow
                label="Glue to write"
                hint="Code that only connects one layer to another."
                delta_from="7"
                delta_to="0"
                delta_unit="kinds"
                left={glue_left}
                right={glue_right}
            />
        </div>;
}

impl ImportTable -> JsxElement {
    return
        <div className="overflow-hidden rounded-xl border border-border/70">
            <div
                className="hidden grid-cols-[minmax(0,1.6fr)_120px_minmax(0,1fr)] gap-6 border-b border-border/70 bg-muted/30 px-5 py-3 font-mono text-[11px] uppercase tracking-widest text-muted-foreground md:grid"
            >
                <span>You write</span>
                <span>Resolves in</span>
                <span>Compiles to</span>
            </div>
            {for (i, row) in enumerate(_IMPORTS) {
                <div
                    key={str(i)}
                    className="grid grid-cols-1 gap-2 border-b border-border/70 px-5 py-4 last:border-b-0 md:grid-cols-[minmax(0,1.6fr)_120px_minmax(0,1fr)] md:items-center md:gap-6"
                >
                    <code
                        className="overflow-x-auto whitespace-pre font-mono text-[13px] text-foreground"
                    >
                        {row["code"]}
                    </code>
                    <span className="font-mono text-xs text-primary">{row["eco"]}</span>
                    <span className="text-sm text-muted-foreground">{row["out"]}</span>
                </div>
            }}
        </div>;
}

impl OneLanguage -> JsxElement {
    has detailed: bool = False;

    return
        <HomeSection id="one-language">
            <SectionHead
                num="01"
                kicker="One language"
                title="One universal language."
            />
            <Figure
                label="fig. 1"
                caption="Many languages and frameworks become one, and the compiler targets every platform from that single program."
            >
                <ConvergeDiagram/>
                <div className="mt-8 border-t border-border/70 pt-6">
                    <button
                        onClick={lambda { detailed = not detailed; }}
                        aria-expanded={detailed}
                        className="group flex w-full items-center justify-between gap-4 text-left"
                    >
                        <span>
                            <span
                                className="block text-sm font-semibold tracking-tight"
                            >
                                {"Hide the detailed view"
                                    if detailed
                                    else "Show the detailed view"}
                            </span>
                        </span>
                        <span
                            className={cn(
                                "flex size-9 shrink-0 items-center justify-center rounded-full border border-border text-muted-foreground transition-transform group-hover:border-primary group-hover:text-primary",
                                "rotate-180" if detailed else ""
                            )}
                        >
                            ↓
                        </span>
                    </button>
                    {if detailed {
                        <div className="anim-fade-in mt-8">
                            <StackCompare/>
                        </div>
                    }}
                </div>
            </Figure>
            <Figure
                label="fig. 2"
                caption="One import statement reaches PyPI, npm and C libraries, resolved by where the code runs."
            >
                <ImportTable/>
            </Figure>
            <Reveal delay={150}>
                <div className="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-3">
                    <Fact
                        title="One syntax"
                        body="An agent holds one syntax in context instead of five and spends its tokens on the problem."
                    />
                    <Fact
                        title="One type checker"
                        body="Mismatches between server, browser and native code are compile errors, not runtime bugs."
                    />
                    <Fact
                        title="A binary that explains itself"
                        body="`jac guide` and `jac mcp` give an agent the full manual, offline."
                    />
                </div>
            </Reveal>
        </HomeSection>;
}
