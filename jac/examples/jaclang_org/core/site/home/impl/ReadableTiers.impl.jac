impl ScopeBars -> JsxElement {
    return
        <div className="flex flex-col gap-3">
            {for s in _SCOPES {
                <div
                    key={s["tier"]}
                    className="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-4"
                >
                    <span
                        className="w-52 shrink-0 font-mono text-xs text-muted-foreground"
                    >
                        <span className="text-primary">{"tier " + s["tier"]}</span>
                        {" · " + s["name"]}
                    </span>
                    <div className="min-w-0 flex-1">
                        <div
                            className="flex h-9 items-center rounded-md border border-primary/40 bg-primary/[0.08] px-3"
                            style={{"width": s["width"], "minWidth": "max-content"}}
                        >
                            <span className="truncate text-xs text-foreground">
                                {s["scope"]}
                            </span>
                        </div>
                    </div>
                </div>
            }}
        </div>;
}

impl CheckLink(text: str) -> JsxElement {
    return
        <div className="relative flex gap-4 py-6 pl-[19px]">
            <span className="w-px shrink-0 bg-border"></span>
            <p className="max-w-2xl pl-5 text-sm leading-relaxed text-muted-foreground">
                <span
                    className="mr-2 font-mono text-xs uppercase tracking-widest text-primary"
                >
                    checked
                </span>
                <Prose text={text}/>
            </p>
        </div>;
}

impl TierRow(
    tier: str, name: str, question: str, file: str, when: str, lines: list[str]
) -> JsxElement {
    return
        <div
            className="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)] lg:gap-10"
        >
            <div className="flex gap-5">
                <span
                    className="flex size-10 shrink-0 items-center justify-center rounded-full border border-primary/60 font-mono text-sm text-primary"
                >
                    {tier}
                </span>
                <div className="min-w-0">
                    <h3 className="text-xl font-semibold tracking-tight">{name}</h3>
                    <p className="mt-1 text-base text-foreground/90">{question}</p>
                    <p className="mt-3 font-mono text-xs text-muted-foreground">
                        {file}
                    </p>
                    <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                        <Prose text={when}/>
                    </p>
                </div>
            </div>
            <CodeWindow lines={lines} title={file} className="self-start"/>
        </div>;
}

impl ReadableTiers -> JsxElement {
    return
        <HomeSection id="readable">
            <SectionHead
                num="04"
                kicker="Readable in tiers"
                title="Readable and verifiable, one tier at a time."
            />
            <Figure
                label="fig. 7"
                caption="Each tier holds more code than the one above it, so most questions are answered before reaching the largest."
            >
                <ScopeBars/>
            </Figure>
            <Figure
                label="fig. 8"
                caption="All three tiers, quoted from the repository serving this page."
            >
                <div className="flex flex-col">
                    <TierRow
                        tier="1"
                        name="Wiring"
                        question="Which modules feed which?"
                        file="archwire.jac"
                        when="Declares which modules may depend on which, and generates every import between them."
                        lines={_ARCH_LINES}
                    />
                    <CheckLink
                        text="An undeclared import or an unused wire is a compile error, so the map cannot drift from the code."
                    />
                    <TierRow
                        tier="2"
                        name="Declarations"
                        question="What does this module promise?"
                        file="core/github.jac"
                        when="Types and signatures without bodies, small enough to hand an agent whole."
                        lines={_DECL_LINES}
                    />
                    <CheckLink
                        text="Callers are type-checked against these signatures, so a body can change without re-reading them."
                    />
                    <TierRow
                        tier="3"
                        name="Implementations"
                        question="How does it actually work?"
                        file="core/impl/github.impl.jac"
                        when="The bodies, which you open only to change behaviour."
                        lines={_IMPL_LINES}
                    />
                </div>
            </Figure>
            <Reveal delay={150}>
                <div className="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-3">
                    <Fact
                        title="Agents read less"
                        body="Locating code takes tier 1, using it takes tier 2, and only changing behaviour opens tier 3."
                    />
                    <Fact
                        title="Architecture shows up in review"
                        body="A new dependency is a one-line diff to `archwire.jac`, not an import buried in some file."
                    />
                    <Fact
                        title="The diagram is the system"
                        body="`jac arch graph` draws the wiring, which stays current because it generates the imports."
                    />
                </div>
            </Reveal>
        </HomeSection>;
}
