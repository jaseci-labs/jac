import from .ui.button { Button }


def:pub BuiltWithJac() -> JsxElement {
    def handle_github() -> None {
        globalThis.open("https://github.com/Jaseci-Labs/jaseci", "_blank");
    }

    def handle_docs() -> None {
        globalThis.open("https://docs.jaseci.org", "_blank");
    }

    stats = [
        {"value": "100%", "label": "Written in Jac", "sub": "Built with the language it serves"},
        {"value": "23", "label": "Built-in tools", "sub": "Filesystem, git, web, Jac-native"},
        {"value": "MIT", "label": "Open source", "sub": "Free to use, inspect, and extend"}
    ];

    return (
        <section className="relative py-32 px-6 section-glow">
            <div className="max-w-5xl mx-auto">
                <div className="text-center mb-16">
                    <div className="section-label mx-auto mb-5 w-fit">Open Source</div>
                    <h2 className="text-4xl md:text-5xl font-bold tracking-[-0.02em] mb-5">
                        <span className="gradient-text-subtle">Built with Jac. For Jac.</span>
                    </h2>
                    <p className="text-white/40 text-base md:text-lg max-w-xl mx-auto leading-relaxed">
                        JacCoder is fully open source and written entirely in Jac. Inspect the code, extend the tools, or contribute.
                    </p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-14">
                    {[
                        <div key={s["label"]} className="glass spot-card text-center p-8">
                            <div className="relative z-[2]">
                                <div className="text-4xl md:text-5xl font-bold gradient-text mb-2">{s["value"]}</div>
                                <div className="text-white/80 font-medium text-sm mb-1">{s["label"]}</div>
                                <div className="text-white/25 text-xs">{s["sub"]}</div>
                            </div>
                        </div>
                        for s in stats
                    ]}
                </div>

                <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
                    <Button size="lg" variant="outline" onClick={handle_github} className="inline-flex items-center gap-2.5 h-12 px-7 rounded-xl text-[0.9375rem] font-semibold border-white/10 hover:border-white/20 hover:bg-white/[0.03]">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                        </svg>
                        View on GitHub
                    </Button>
                    <Button size="lg" variant="ghost" onClick={handle_docs} className="inline-flex items-center gap-2 h-12 px-7 rounded-xl text-[0.9375rem] font-semibold text-white/50 hover:text-white/80">
                        Read the docs
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M7 17L17 7M17 7H7M17 7v10"></path>
                        </svg>
                    </Button>
                </div>
            </div>
        </section>
    );
}
