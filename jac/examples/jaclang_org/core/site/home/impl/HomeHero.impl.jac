impl HomeHero -> JsxElement {
    def go(sec_id: str) {
        el: any = document.getElementById(sec_id);
        if el {
            el.scrollIntoView({"behavior": "smooth", "block": "start"});
        }
    }

    return
        <section id="top" className="pt-36 pb-20 sm:pt-44 sm:pb-28">
            <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
                <p
                    className="anim-fade-up font-mono text-xs uppercase tracking-[0.2em] text-muted-foreground"
                >
                    The Jac programming language
                </p>
                <h1
                    className="anim-fade-up anim-d1 mt-6 max-w-4xl text-balance text-5xl font-semibold tracking-tight sm:text-6xl lg:text-7xl"
                >
                    The ultimate language for agents to build{" "}
                    <span className="text-primary">everything</span>
                    .
                </h1>
                <div className="anim-fade-up anim-d2 mt-10 max-w-4xl">
                    <p className="text-lg leading-8 text-muted-foreground sm:text-xl">
                        Install Jac's single binary with this command:
                    </p>
                    <div
                        className="mt-4 flex flex-col-reverse gap-2 lg:flex-row lg:items-center lg:gap-5"
                    >
                        <div className="relative w-full lg:max-w-xl">
                            <CopyCommand
                                command={NEOJAC_INSTALL}
                                className="cmd-glow w-full border-primary/60 bg-card"
                            />
                            <span
                                aria-hidden="true"
                                className="sticker-wiggle pointer-events-none absolute -left-4 -top-4 z-10 select-none rounded-md bg-primary px-2 py-0.5 font-mono text-[11px] font-bold uppercase tracking-wider text-primary-foreground shadow-lg shadow-primary/40"
                            >
                                neojac
                            </span>
                        </div>
                        <span
                            className="self-start whitespace-nowrap rounded-full border border-primary/40 bg-primary/10 px-3 py-1 font-mono text-xs uppercase tracking-[0.15em] text-primary lg:self-auto"
                        >
                            Jac's most advanced compiler
                        </span>
                    </div>
                    <div
                        className="mt-4 flex flex-col-reverse gap-2 lg:flex-row lg:items-center lg:gap-5"
                    >
                        <CopyCommand
                            command={HOME_INSTALL}
                            className="w-full lg:max-w-xl"
                        />
                        <span
                            className="self-start whitespace-nowrap rounded-full border border-border px-3 py-1 font-mono text-xs uppercase tracking-[0.15em] text-muted-foreground lg:self-auto"
                        >
                            Jac's reference compiler
                        </span>
                    </div>
                    <p
                        className="mt-8 text-lg leading-8 text-muted-foreground sm:text-xl"
                    >
                        Then give your agent this prompt:
                    </p>
                    <CopyCommand
                        command={HOME_PROMPT}
                        prefix="›"
                        className="mt-4 w-full lg:max-w-xl"
                    />
                </div>
                <ol
                    className="anim-fade-up anim-d4 mt-20 grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-2 lg:mt-28 lg:grid-cols-4"
                >
                    {for p in _PILLARS {
                        <li key={p["id"]}>
                            <button
                                onClick={lambda { go(p["id"]); }}
                                className="group block w-full border-t border-border pt-5 text-left transition-colors hover:border-primary"
                            >
                                <span className="font-mono text-xs text-primary">
                                    {p["num"]}
                                </span>
                                <span
                                    className="mt-2 block text-base font-semibold tracking-tight transition-colors group-hover:text-primary"
                                >
                                    {p["title"]}
                                </span>
                            </button>
                        </li>
                    }}
                </ol>
            </div>
        </section>;
}
