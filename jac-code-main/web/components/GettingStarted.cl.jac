import from .ui.button { Button }


def:pub GettingStarted() -> JsxElement {
    has copied_index: int = -1;

    def copy_cmd(cmd: str, idx: int) -> None {
        globalThis.navigator.clipboard.writeText(cmd);
        copied_index = idx;
    }

    def copy_install() -> None { copy_cmd("pip install jac-coder", 0); }
    def copy_run() -> None { copy_cmd("jac-coder", 1); }

    def handle_marketplace() -> None {
        globalThis.open("https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jac-coder", "_blank");
    }

    return (
        <section id="getting-started" className="relative py-32 px-6 section-glow">
            <div className="max-w-5xl mx-auto">
                <div className="text-center mb-16">
                    <div className="section-label mx-auto mb-5 w-fit">Get Started</div>
                    <h2 className="text-4xl md:text-5xl font-bold tracking-[-0.02em] mb-5">
                        <span className="gradient-text-subtle">Up and running in under a minute</span>
                    </h2>
                    <p className="text-white/40 text-base md:text-lg max-w-lg mx-auto leading-relaxed">
                        Pick your workflow. Both give you the full agent.
                    </p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                    <div className="glass glass-primary spot-card p-8">
                        <div className="relative z-[2]">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="w-11 h-11 rounded-xl bg-orange-500/8 border border-orange-500/12 flex items-center justify-center">
                                    <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" className="text-orange-400">
                                        <path d="M17.583 2.603L9.88 8.71 5.83 5.612l-1.83.925v10.933l1.837.918 4.043-3.09 7.703 6.107 2.417-1.18V3.783l-2.417-1.18zM9.56 15.291l-3.606 2.764V5.952l3.606 2.764v6.575zm8.023 3.073l-6.205-4.907V10.55l6.205-4.907v12.72z"/>
                                    </svg>
                                </div>
                                <div>
                                    <h3 className="text-lg font-semibold text-white">VS Code Extension</h3>
                                    <p className="text-white/30 text-xs">Recommended</p>
                                </div>
                            </div>

                            <p className="text-white/35 text-sm mb-6 leading-relaxed">
                                Inline chat, real-time file diffs, and tool activity — directly inside your editor.
                            </p>

                            <Button size="lg" onClick={handle_marketplace} className="w-full justify-center gap-2 h-11 rounded-xl text-sm font-semibold shadow-[0_0_20px_-4px_rgba(249,115,22,0.25)]">
                                Install from Marketplace
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <path d="M7 17L17 7M17 7H7M17 7v10"></path>
                                </svg>
                            </Button>
                        </div>
                    </div>

                    <div className="glass spot-card p-8">
                        <div className="relative z-[2]">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="w-11 h-11 rounded-xl bg-white/[0.04] border border-white/[0.06] flex items-center justify-center">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-white/50">
                                        <path d="M8 9l3 3-3 3m5 0h3"></path>
                                        <rect x="3" y="4" width="18" height="16" rx="2"></rect>
                                    </svg>
                                </div>
                                <div>
                                    <h3 className="text-lg font-semibold text-white">CLI</h3>
                                    <p className="text-white/30 text-xs">Python 3.11+</p>
                                </div>
                            </div>

                            <div className="space-y-2.5 mb-6">
                                <div className="code-block px-4 py-2.5 flex items-center justify-between gap-3 rounded-lg">
                                    <code className="text-emerald-400/70 font-mono text-[0.8125rem]">
                                        <span className="text-orange-400/70">$</span> pip install jac-coder
                                    </code>
                                    <button onClick={copy_install} className="text-[0.6875rem] text-white/20 hover:text-white/50 transition-colors flex-shrink-0">
                                        {copied_index == 0 and "Copied!" or "Copy"}
                                    </button>
                                </div>
                                <div className="code-block px-4 py-2.5 flex items-center justify-between gap-3 rounded-lg">
                                    <code className="text-emerald-400/70 font-mono text-[0.8125rem]">
                                        <span className="text-orange-400/70">$</span> jac-coder
                                    </code>
                                    <button onClick={copy_run} className="text-[0.6875rem] text-white/20 hover:text-white/50 transition-colors flex-shrink-0">
                                        {copied_index == 1 and "Copied!" or "Copy"}
                                    </button>
                                </div>
                            </div>

                            <p className="text-white/25 text-xs">
                                Run in your project directory. Supports 100+ LLMs via byllm.
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
