impl GlueMap -> JsxElement {
    has active: int = 0;

    cur = _GLUE[active];
    return
        <div
            className="grid grid-cols-1 gap-8 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]"
        >
            <div className="min-w-0">
                <p
                    className="mb-3 font-mono text-[11px] uppercase tracking-widest text-muted-foreground"
                >
                    What the agent writes · 23 lines
                </p>
                <CodeWindow
                    lines={_TODO_LINES}
                    title="todo.jac"
                    numbers={True}
                    hl_from={cur["from"] as int}
                    hl_to={cur["to"] as int}
                />
                {if (cur["from"] as int) == 0 {
                    <div
                        className="code-window mt-3 rounded-xl px-5 py-3 font-mono text-[13px]"
                    >
                        <span className="sh-prompt">$ </span>
                        <span className="sh-cmd">jac scale deploy</span>
                    </div>
                }}
            </div>
            <div className="min-w-0">
                <p
                    className="mb-3 font-mono text-[11px] uppercase tracking-widest text-muted-foreground"
                >
                    What the compiler writes instead
                </p>
                <ol className="flex flex-col">
                    {for (i, g) in enumerate(_GLUE) {
                        <li key={str(i)}>
                            <button
                                onClick={lambda { active = i; }}
                                onMouseEnter={lambda { active = i; }}
                                className={cn(
                                    "block w-full border-l-2 py-3 pr-2 pl-4 text-left transition-colors",
                                    "border-primary bg-primary/[0.06]"
                                        if i == active
                                        else "border-border hover:border-primary/50"
                                )}
                            >
                                <span className="flex items-baseline gap-3">
                                    <span className="font-mono text-xs text-primary">
                                        {str(i + 1)}
                                    </span>
                                    <span
                                        className="text-sm font-semibold tracking-tight"
                                    >
                                        <Prose text={g["title"]}/>
                                    </span>
                                </span>
                                {if i == active {
                                    <span className="mt-2 block pl-6">
                                        <span
                                            className="block text-sm leading-relaxed text-muted-foreground"
                                        >
                                            <Prose text={g["body"]}/>
                                        </span>
                                        <span className="mt-3 flex flex-wrap gap-1.5">
                                            {for (j, f) in enumerate(g["replaces"]) {
                                                <span
                                                    key={str(j)}
                                                    className="strike-chip rounded-md border border-border/80 px-2 py-0.5 font-mono text-[11px] text-muted-foreground"
                                                >
                                                    {f}
                                                </span>
                                            }}
                                        </span>
                                    </span>
                                }}
                            </button>
                        </li>
                    }}
                </ol>
            </div>
        </div>;
}

impl NoGlue -> JsxElement {
    return
        <HomeSection id="no-glue">
            <SectionHead
                num="02"
                kicker="No glue"
                title="The compiler writes the glue."
            />
            <Figure
                label="fig. 3"
                caption="Pick a row to see which lines replace which hand-written files; the struck-through ones never exist in Jac."
            >
                <GlueMap/>
            </Figure>
            <Reveal delay={150}>
                <div className="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-3">
                    <Fact
                        title="Less to write"
                        body="The agent writes the application rather than its scaffolding, in fewer tokens and turns."
                    />
                    <Fact
                        title="Less to get wrong"
                        body="Generated glue cannot drift, so a renamed field breaks the build rather than production."
                    />
                    <Fact
                        title="A tighter loop"
                        body="`jac run --dev` hot-reloads, so the agent sees each change working in seconds."
                    />
                </div>
            </Reveal>
        </HomeSection>;
}
