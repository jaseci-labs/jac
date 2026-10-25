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
                <div className="anim-fade-up anim-d2 mt-10 max-w-xl">
                    <p className="text-lg leading-8 text-muted-foreground sm:text-xl">
                        Install Jac's single binary with this command:
                    </p>
                    <CopyCommand command={HOME_INSTALL} className="mt-4 w-full"/>
                    <p
                        className="mt-8 text-lg leading-8 text-muted-foreground sm:text-xl"
                    >
                        Then give your agent this prompt:
                    </p>
                    <CopyCommand
                        command={HOME_PROMPT}
                        prefix="›"
                        className="mt-4 w-full"
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
