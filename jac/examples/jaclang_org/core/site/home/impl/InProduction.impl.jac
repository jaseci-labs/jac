impl ReductionBars -> JsxElement {
    has hover: int = -1;

    return
        <div className="min-w-0">
            <div className="relative">
                {for t in _TICKS {
                    <span
                        key={t["label"]}
                        className="absolute top-0 bottom-6 w-px bg-border/70"
                        style={{"left": pct(t["v"])}}
                    ></span>
                }}
                <div className="relative flex flex-col gap-9 pt-1 pb-8">
                    {for (i, b) in enumerate(_BARS) {
                        <div
                            key={b["when"]}
                            className="relative"
                            onMouseEnter={lambda { hover = i; }}
                            onMouseLeave={lambda { hover = -1; }}
                        >
                            <p className="mb-2 flex items-baseline gap-2 text-sm">
                                <span
                                    className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground"
                                >
                                    {b["when"]}
                                </span>
                                <span className="font-medium text-foreground">
                                    {b["name"]}
                                </span>
                            </p>
                            <div className="flex h-6 items-center gap-3">
                                <div
                                    className="h-6 rounded-r-[4px] transition-opacity"
                                    style={{
                                        "width": pct(b["lines"]),
                                        "minWidth": "6px",
                                        "backgroundColor": "#ff6b35"
                                            if b["hot"]
                                            else "var(--muted-foreground)",
                                        "opacity": "1"
                                            if (hover == -1 or hover == i)
                                            else "0.45"
                                    }}
                                ></div>
                                <span
                                    className="shrink-0 text-sm font-semibold tabular-nums text-foreground"
                                >
                                    {b["shown"]}
                                </span>
                            </div>
                            {if hover == i {
                                <div
                                    role="tooltip"
                                    className="absolute top-full left-0 z-10 mt-2 rounded-md border border-border bg-popover px-3 py-2 text-xs text-popover-foreground shadow-md"
                                >
                                    <span className="font-semibold tabular-nums">
                                        {b["shown"]}
                                    </span>{" "}
                                    {b["note"]}
                                </div>
                            }}
                        </div>
                    }}
                </div>
                <div className="relative h-5">
                    {for t in _TICKS {
                        <span
                            key={t["label"]}
                            className="absolute -translate-x-1/2 font-mono text-[10px] tabular-nums text-muted-foreground"
                            style={{"left": pct(t["v"])}}
                        >
                            {t["label"]}
                        </span>
                    }}
                </div>
            </div>
            <p className="mt-2 text-xs text-muted-foreground">lines of code</p>
            <table className="sr-only">
                <caption>Lines of code before and after the rewrite</caption>
                <thead>
                    <tr>
                        <th>Codebase</th>
                        <th>Lines</th>
                    </tr>
                </thead>
                <tbody>
                    {for b in _BARS {
                        <tr key={b["when"]}>
                            <td>{b["when"] + ": " + b["name"]}</td>
                            <td>{b["shown"]}</td>
                        </tr>
                    }}
                </tbody>
            </table>
        </div>;
}

impl InProduction -> JsxElement {
    return
        <HomeSection id="in-production">
            <SectionHead
                num=""
                kicker="In production"
                title="A production platform, rewritten in Jac."
                lede="A startup's production Next.js and Supabase platform was rewritten in pure Jac with pixel-perfect parity. The entire TypeScript codebase was replaced with Jac plus a single `jac.toml`."
            />
            <Figure
                label="fig. 4"
                caption="Lines in the rewrite's diff; hover a bar for what it counts."
            >
                <div
                    className="grid grid-cols-1 items-center gap-10 lg:grid-cols-[minmax(0,260px)_minmax(0,1fr)] lg:gap-14"
                >
                    <div>
                        <p
                            className="text-6xl font-semibold tracking-tight text-foreground sm:text-7xl"
                        >
                            20×
                        </p>
                        <p className="mt-2 text-base font-medium">less code</p>
                        <p
                            className="mt-4 text-sm leading-relaxed text-muted-foreground"
                        >
                            95% fewer lines for the same product.
                        </p>
                    </div>
                    <ReductionBars/>
                </div>
                <div
                    className="mt-10 flex flex-col gap-4 border-t border-border/70 pt-6 sm:flex-row sm:items-center sm:justify-between"
                >
                    <div>
                        <p
                            className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground"
                        >
                            The receipt
                        </p>
                        <p className="mt-1 text-sm text-muted-foreground">
                            The rewrite's own diff stat.
                        </p>
                    </div>
                    <div
                        className="code-window shrink-0 self-start overflow-hidden rounded-lg"
                    >
                        <img
                            src="/static/assets/case-study-diffstat.png"
                            alt="Diff stat: plus 30,282 lines, minus 604,840 lines"
                            className="block h-auto w-[280px] sm:w-[340px]"
                        />
                    </div>
                </div>
            </Figure>
            <Reveal delay={150}>
                <div className="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-3">
                    <Fact
                        title="Same product"
                        body="Pixel-perfect parity, so the only difference is the code."
                    />
                    <Fact
                        title="One language, one config"
                        body="Next.js, TypeScript and the Supabase integration became pure Jac and a single `jac.toml`."
                    />
                    <Fact
                        title="574,558 lines gone"
                        body="Lines nobody has to read, review, test or keep in sync again."
                    />
                </div>
            </Reveal>
        </HomeSection>;
}
