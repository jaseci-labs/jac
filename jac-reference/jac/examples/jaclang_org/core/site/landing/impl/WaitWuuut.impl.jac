impl Definition(
    term: str, pos: str, body: str, ipa: str = "", ety: str = "", num: int = 0
) -> JsxElement {
    return
        <div
            className="relative overflow-hidden rounded-xl border border-border/50 bg-card/40 pl-6 pr-5 pt-4 pb-4 text-left"
        >
            <div
                className="absolute inset-y-0 left-0 w-[3px] bg-gradient-to-b from-[#f7931e] via-[#ff6b35] to-[#e8442c]"
            ></div>
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <span className="text-gradient text-xl font-bold tracking-tight">
                    {term}
                </span>
                {if ipa != "" {
                    <span className="font-mono text-xs text-muted-foreground/60">
                        {ipa}
                    </span>
                }}
                <span className="text-xs italic text-muted-foreground/70">{pos}</span>
                {if num > 0 {
                    <span
                        className="ml-auto font-mono text-[10px] uppercase tracking-widest text-muted-foreground/40"
                    >
                        {"dfn "}{str(num)}
                    </span>
                }}
            </div>
            {if ety != "" {
                <p className="mt-1 text-xs italic text-muted-foreground/50">{ety}</p>
            }}
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{body}</p>
        </div>;
}

impl DefCard(k: str) -> JsxElement {
    d = DEFS[k] as dict[str, any];
    return
        <Definition
            term={d["term"] as str}
            pos={d["pos"] as str}
            body={d["body"] as str}
            ipa={d["ipa"] as str}
            ety={d["ety"] as str}
            num={d["num"] as int}
        />;
}

impl LexiconSection -> JsxElement {
    return
        <div id="g-lexicon" className="scroll-mt-24">
            <div className="mx-auto max-w-5xl pl-4 pr-4 pt-24 pb-8 sm:pl-6 sm:pr-6">
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            Jac's contribution is{" "}
                            <span className="text-gradient">fundamental</span>
                        </h2>
                        <p className="mt-3 text-balance text-muted-foreground">
                            Jac is not a language that recombines familiar features, it introduces concepts programming languages have not had before. The working lexicon, in one place:
                        </p>
                    </div>
                    <div className="mx-auto mt-10 flex max-w-3xl flex-col gap-4">
                        {for k in LEX_ORDER {
                            <div key={k as str}>
                                <DefCard k={k as str}/>
                            </div>
                        }}
                    </div>
                    <p
                        className="mx-auto mt-8 max-w-2xl text-center text-sm text-muted-foreground/70"
                    >
                        Every definition above was demonstrated by running code from this site's own source before it was restated here.
                    </p>
                </Reveal>
            </div>
        </div>;
}

impl AbsentSection -> JsxElement {
    return
        <div id="g-absent" className="scroll-mt-24">
            <div className="mx-auto max-w-5xl pl-4 pr-4 pt-20 pb-6 sm:pl-6 sm:pr-6">
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            What you{" "}
                            <span className="text-gradient">won't see</span>
                        </h2>
                        <p className="mt-3 text-balance text-muted-foreground">
                            A full-stack site usually drags an entourage. Everything below is genuinely absent from this source tree: not generated and hidden, absorbed by the language.
                        </p>
                    </div>
                    <div
                        className="mx-auto mt-10 grid max-w-4xl grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3"
                    >
                        {for (i, a) in enumerate(ABSENT) {
                            <div
                                key={str(i)}
                                className="rounded-xl border border-border/50 bg-card/40 p-4 text-left"
                            >
                                <p
                                    className="font-mono text-sm text-muted-foreground/60 line-through decoration-primary/60"
                                >
                                    {a["thing"] as str}
                                </p>
                                <p className="mt-1.5 text-xs text-muted-foreground">
                                    {a["why"] as str}
                                </p>
                            </div>
                        }}
                    </div>
                </Reveal>
            </div>
        </div>;
}

impl GroupHeader(pre: str, hot: str, post: str, blurb: str) -> JsxElement {
    return
        <div className="mx-auto max-w-5xl pl-4 pr-4 pt-24 pb-2 sm:pl-6 sm:pr-6">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <h2
                        className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                    >
                        {pre}
                        <span className="text-gradient">{hot}</span>
                        {post}
                    </h2>
                    <p className="mt-3 text-balance text-muted-foreground">{blurb}</p>
                </div>
            </Reveal>
        </div>;
}

impl FeatureSection(idx: int, data: dict[str, any], on_pop: any) -> JsxElement {
    flipped = idx % 2 == 1;
    return
        <section className="border-t border-border/40 pt-14 pb-14">
            <Reveal>
                <div
                    className={"mx-auto flex max-w-7xl flex-col gap-8 pl-4 pr-4 sm:pl-6 sm:pr-6 lg:items-center lg:gap-14 lg:pl-8 lg:pr-8 "
                        + ("lg:flex-row-reverse" if flipped else "lg:flex-row")}
                >
                    <div className="shrink-0 lg:w-[38%]">
                        <Badge variant="outline" className="mb-4 font-mono">
                            {str(idx + 1)}{" · "}{data["tag"] as str}
                        </Badge>
                        <h3
                            className="text-balance text-2xl font-bold tracking-tight sm:text-3xl"
                        >
                            {data["title"] as str}
                        </h3>
                        <p className="mt-4 text-muted-foreground">
                            {data["body"] as str}
                        </p>
                        <p className="mt-3 font-mono text-xs text-muted-foreground/70">
                            {data["path"] as str}
                        </p>
                        {if "path2" in data {
                            <p
                                className="mt-1 font-mono text-xs text-muted-foreground/70"
                            >
                                {"+ "}{data["path2"] as str}
                            </p>
                        }}
                    </div>
                    {if "path2" in data {
                        <div className="flex min-w-0 flex-1 flex-col gap-4">
                            <CodeSpotlight
                                path={data["path"] as str}
                                needle={data["needle"] as str}
                                hl_lines={data["hl"] as int}
                                before={data["before"] as int}
                                after={data["after"] as int}
                                on_pop={on_pop}
                            />
                            <CodeSpotlight
                                path={data["path2"] as str}
                                needle={data["needle2"] as str}
                                hl_lines={data["hl2"] as int}
                                before={data["before2"] as int}
                                after={data["after2"] as int}
                                on_pop={on_pop}
                                compact={True}
                            />
                        </div>
                    } else {
                        <CodeSpotlight
                            className="min-w-0 flex-1"
                            path={data["path"] as str}
                            needle={data["needle"] as str}
                            hl_lines={data["hl"] as int}
                            before={data["before"] as int}
                            after={data["after"] as int}
                            on_pop={on_pop}
                        />
                    } }
                </div>
            </Reveal>
        </section>;
}

impl WaitWuuut -> JsxElement {
    has popped: str = "",
        pop_seq: int = 0;

    def handle_pop(path: str) {
        popped = path;
        pop_seq = pop_seq + 1;
    }

    bases: list[int] = [];
    running = 0;
    for grp in GROUPS {
        bases.append(running);
        running += len(grp["sections"] as list[dict[str, any]]);
    }
    return
        <div className="pb-24">
            <section className="pt-32 pb-4 sm:pt-40">
                <div
                    className="mx-auto max-w-3xl pl-4 pr-4 text-center sm:pl-6 sm:pr-6"
                >
                    <Badge variant="outline" className="mb-4">Feature Deep Dive</Badge>
                    <h1
                        className="text-balance text-4xl font-bold tracking-tight sm:text-6xl"
                    >
                        Wait,{" "}
                        <span className="text-gradient">Wuuut?!</span>
                    </h1>
                    <p className="mt-5 text-balance text-lg text-muted-foreground">
                        A tour of the language features running this exact site. Every window below is a real source file of jaclang.org, fetched live from the server you are on and scrolled to the lines that do the thing. Scroll around in any window and it will drift back home; pop one out to roam the whole tree. Nothing is a mock; if we broke a file, its section would say so.
                    </p>
                </div>
            </section>
            <AbsentSection/>
            <SectionRail items={NAV_ITEMS}/>
            {for (gi, grp) in enumerate(GROUPS) {
                <div
                    key={grp["key"] as str}
                    id={"g-" + (grp["key"] as str)}
                    className="scroll-mt-24"
                >
                    <GroupHeader
                        pre={grp["pre"] as str}
                        hot={grp["hot"] as str}
                        post={grp["post"] as str}
                        blurb={grp["blurb"] as str}
                    />
                    {if "define" in grp {
                        <div
                            className="mx-auto max-w-3xl pl-4 pr-4 pt-8 sm:pl-6 sm:pr-6"
                        >
                            <Reveal>
                                <DefCard k={grp["define"] as str}/>
                            </Reveal>
                        </div>
                    }}
                    {for (si, s) in enumerate(
                        grp["sections"] as list[dict[str, any]]
                    ) {
                        <div key={str(si)}>
                            {if "define" in (s as dict[str, any]) {
                                <div
                                    className="mx-auto max-w-3xl pl-4 pr-4 pt-10 pb-2 sm:pl-6 sm:pr-6"
                                >
                                    <Reveal>
                                        <DefCard
                                            k={(s as dict[str, any])["define"] as str}
                                        />
                                    </Reveal>
                                </div>
                            }}
                            <FeatureSection
                                idx={(bases[gi] as int) + si}
                                data={s as dict[str, any]}
                                on_pop={handle_pop}
                            />
                        </div>
                    }}
                </div>
            }}
            <LexiconSection/>
            {if popped != "" {
                <FloatingSource
                    key={popped + str(pop_seq)}
                    always_float={True}
                    closable={True}
                    initial_path={popped}
                />
            }}
        </div>;
}
