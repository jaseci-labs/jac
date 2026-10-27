impl FpsBars -> JsxElement {
    has hover: int = -1;

    return
        <div className="min-w-0">
            <div className="relative">
                {for t in _FPS_TICKS {
                    <span
                        key={t["label"]}
                        className="absolute top-0 bottom-6 w-px bg-border/70"
                        style={{"left": fps_pct(t["v"])}}
                    ></span>
                }}
                <div className="relative flex flex-col gap-7 pt-1 pb-8">
                    {for (i, r) in enumerate(_RUNS) {
                        <div
                            key={r["lang"]}
                            className="relative"
                            onMouseEnter={lambda { hover = i; }}
                            onMouseLeave={lambda { hover = -1; }}
                        >
                            <p className="mb-2 flex items-baseline gap-2 text-sm">
                                <span className="font-medium text-foreground">
                                    {r["lang"]}
                                </span>
                                <span
                                    className="font-mono text-[11px] text-muted-foreground"
                                >
                                    {r["build"]}
                                </span>
                            </p>
                            <div className="flex h-6 items-center gap-3">
                                <div
                                    className="h-6 rounded-r-[4px] transition-opacity"
                                    style={{
                                        "width": fps_pct(r["fps"]),
                                        "backgroundColor": "#ff6b35"
                                            if r["hot"]
                                            else "var(--muted-foreground)",
                                        "opacity": "1"
                                            if (hover == -1 or hover == i)
                                            else "0.45"
                                    }}
                                ></div>
                                <span
                                    className="shrink-0 text-sm font-semibold tabular-nums text-foreground"
                                >
                                    {r["shown"]}
                                </span>
                            </div>
                            {if hover == i {
                                <div
                                    role="tooltip"
                                    className="absolute top-full left-0 z-10 mt-2 rounded-md border border-border bg-popover px-3 py-2 text-xs text-popover-foreground shadow-md"
                                >
                                    <span className="font-semibold tabular-nums">
                                        {r["shown"]} FPS
                                    </span>{" "}
                                    {"average, " + r["frames"] + " frames in 8 s"}
                                </div>
                            }}
                        </div>
                    }}
                </div>
                <div className="relative h-5">
                    {for t in _FPS_TICKS {
                        <span
                            key={t["label"]}
                            className="absolute -translate-x-1/2 font-mono text-[10px] tabular-nums text-muted-foreground"
                            style={{"left": fps_pct(t["v"])}}
                        >
                            {t["label"]}
                        </span>
                    }}
                </div>
            </div>
            <p className="mt-2 text-xs text-muted-foreground">
                average frames per second, uncapped
            </p>
            <table className="sr-only">
                <caption>Average FPS of the raylib cube shooter, by language</caption>
                <thead>
                    <tr>
                        <th>Language</th>
                        <th>Average FPS</th>
                        <th>Frames in 8 seconds</th>
                    </tr>
                </thead>
                <tbody>
                    {for r in _RUNS {
                        <tr key={r["lang"]}>
                            <td>{r["lang"]}</td>
                            <td>{r["shown"]}</td>
                            <td>{r["frames"]}</td>
                        </tr>
                    }}
                </tbody>
            </table>
        </div>;
}

impl NativeBench -> JsxElement {
    return
        <HomeSection id="benchmark">
            <SectionHead
                num=""
                kicker="Benchmark"
                title="Rust-level performance, measured."
            >
                <p
                    className="mt-6 max-w-2xl text-pretty text-lg leading-8 text-muted-foreground"
                >
                    The benchmark is a raylib cube shooter written line for line in Jac, Zig, Rust and Python. To play a Jac game compiled to WebAssembly in your browser,{" "}
                    <Link
                        to="/tech-demo"
                        className="font-medium text-primary underline-offset-4 hover:underline"
                    >
                        try the arena in the tech demo →
                    </Link>
                </p>
            </SectionHead>
            <Figure
                label="fig. 5"
                caption="Average FPS over 8-second uncapped runs on an Apple M5 Max, where single runs vary by a few percent; Python is CPython 3.14.6 via `ctypes`."
            >
                <div
                    className="grid grid-cols-1 items-center gap-10 lg:grid-cols-[minmax(0,260px)_minmax(0,1fr)] lg:gap-14"
                >
                    <div>
                        <p
                            className="text-6xl font-semibold tracking-tight text-foreground sm:text-7xl"
                        >
                            0.4%
                        </p>
                        <p className="mt-2 text-base font-medium">
                            between Jac, Zig and Rust
                        </p>
                        <p
                            className="mt-4 text-sm leading-relaxed text-muted-foreground"
                        >
                            Jac averaged 3,225.9 FPS, between Zig and Rust and twice Python's 1,588.4.
                        </p>
                    </div>
                    <FpsBars/>
                </div>
            </Figure>
            <Reveal delay={150}>
                <div className="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-3">
                    <Fact
                        title="No C toolchain"
                        body="`jac build --native` writes the executable itself, with no `cc` or `ld`."
                    />
                    <Fact
                        title="Same library, same work"
                        body="Every twin binds raylib directly and draws through the same `rlgl` calls."
                    />
                    <Fact
                        title="Run it yourself"
                        body="Run `./demo.sh` in `jac/examples/raylib_shooter` for the native twins and `python3 shooter.py` for Python."
                    />
                </div>
            </Reveal>
        </HomeSection>;
}
