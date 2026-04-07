import from .ui.button { Button }


def:pub FinalCTA() -> JsxElement {
    def handle_install_vsce() -> None {
        globalThis.open("https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jac-coder", "_blank");
    }

    def handle_github() -> None {
        globalThis.open("https://github.com/Jaseci-Labs/jaseci", "_blank");
    }

    return (
        <section className="py-24 px-6">
            <div className="max-w-4xl mx-auto">
                <div className="cta-block">
                    <div className="relative p-12 md:p-20 text-center">
                        <h2 className="text-4xl md:text-5xl font-bold tracking-[-0.02em] mb-4">
                            <span className="gradient-text-subtle">Ready to ship Jac faster?</span>
                        </h2>
                        <p className="text-white/40 text-base md:text-lg max-w-md mx-auto mb-10 leading-relaxed">
                            Install JacCoder and let an agent that understands your codebase do the heavy lifting.
                        </p>
                        <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
                            <Button size="lg" onClick={handle_install_vsce} className="inline-flex items-center gap-2.5 h-12 px-7 rounded-xl text-[0.9375rem] font-semibold shadow-[0_0_24px_-4px_rgba(249,115,22,0.3)]">
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M17.583 2.603L9.88 8.71 5.83 5.612l-1.83.925v10.933l1.837.918 4.043-3.09 7.703 6.107 2.417-1.18V3.783l-2.417-1.18zM9.56 15.291l-3.606 2.764V5.952l3.606 2.764v6.575zm8.023 3.073l-6.205-4.907V10.55l6.205-4.907v12.72z"/>
                                </svg>
                                Install for VS Code
                            </Button>
                            <Button variant="outline" size="lg" onClick={handle_github} className="inline-flex items-center gap-2 h-12 px-7 rounded-xl text-[0.9375rem] font-semibold border-white/10 hover:border-white/20 hover:bg-white/[0.03]">
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                                </svg>
                                Star on GitHub
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
