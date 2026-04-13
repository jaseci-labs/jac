"""Landing page for Jac MCP Studio."""

def:pub HomePage(onEnter: Any) -> JsxElement {
    TOOLS = [
        "validate jac",
        "check syntax",
        "format jac",
        "lint jac",
        "run jac",
        "get ast",
        "graph visualize",
        "py → jac",
        "jac → py",
        "jac → js",
        "explain error",
        "search docs",
        "list examples",
        "get example",
        "list commands",
        "get command",
        "execute command",
        "understand jac & jaseci",
        "get resource"
    ];

    STATS = [
        {"value": "19", "label": "Tools"},
        {"value": "MCP", "label": "Protocol"},
        {"value": "3", "label": "Languages"},
        {"value": "0ms", "label": "Setup"}
    ];

    return
        <div
            className="min-h-screen bg-[#0a0a0b] text-zinc-100 flex flex-col relative overflow-hidden"
        >
            <div
                className="absolute inset-0 bg-[radial-gradient(ellipse_90%_60%_at_50%_-5%,rgba(255,122,24,0.16),transparent)] pointer-events-none"
            />
            <div
                className="absolute inset-0 bg-[radial-gradient(ellipse_50%_40%_at_85%_85%,rgba(120,80,255,0.08),transparent)] pointer-events-none"
            />
            <div
                className="absolute inset-0 bg-[radial-gradient(ellipse_40%_30%_at_5%_70%,rgba(255,122,24,0.05),transparent)] pointer-events-none"
            />
            <div
                className="absolute inset-0 pointer-events-none"
                style={{
                    "backgroundImage": "radial-gradient(circle, rgba(255,255,255,0.03) 1px, transparent 1px)",
                    "backgroundSize": "28px 28px"
                }}
            />
            <nav
                className="relative z-10 flex items-center justify-between px-8 py-5 border-b border-white/[0.04]"
            >
                <div className="flex items-center gap-2.5">
                    <div
                        className="h-7 w-7 rounded-lg bg-gradient-to-br from-orange-400 to-orange-600 flex items-center justify-center shadow-[0_0_16px_rgba(255,122,24,0.45)] flex-shrink-0"
                    >
                        <span className="text-[11px] font-black text-white">J</span>
                    </div>
                    <span className="text-sm font-semibold text-white tracking-tight">
                        Jac MCP Studio
                    </span>
                </div>
            </nav>
            <section
                className="relative z-10 flex flex-col items-center justify-center flex-1 px-6 pt-20 pb-16 text-center"
            >
                <div className="flex flex-col items-center gap-8 max-w-2xl mx-auto">
                    <div
                        className="flex items-center gap-2.5 px-4 py-1.5 rounded-full border border-white/[0.09] bg-white/[0.03]"
                    >
                        <span
                            className="h-1.5 w-1.5 rounded-full bg-orange-400 shadow-[0_0_8px_rgba(255,122,24,0.9)] animate-pulse flex-shrink-0"
                        />
                        <span className="text-[11px] text-zinc-400 tracking-wide">
                            Powered by Model Context Protocol
                        </span>
                    </div>
                    <div className="space-y-5">
                        <h1
                            className="text-[64px] font-extrabold tracking-[-0.03em] leading-[1.02] text-white"
                        >
                            The Developer Studio
                            <br/>
                            <span className="text-orange-400">for Jac.</span>
                        </h1>
                        <p
                            className="text-base text-zinc-400 leading-relaxed max-w-[480px] mx-auto"
                        >
                            Validate, format, run, convert, and explore the Jac programming language. All from one real-time interface powered by MCP.
                        </p>
                    </div>
                    <div className="flex flex-col sm:flex-row items-center gap-3 pt-1">
                        <button
                            onClick={onEnter}
                            className="group flex items-center gap-2.5 px-8 py-3.5 rounded-xl font-semibold text-sm text-white bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-400 hover:to-orange-500 shadow-[0_0_35px_rgba(255,122,24,0.38)] hover:shadow-[0_0_50px_rgba(255,122,24,0.5)] transition-all duration-200"
                        >
                            <span>Explore the Tools</span>
                            <span
                                className="text-orange-200 transition-transform duration-200 group-hover:translate-x-1"
                            >
                                →
                            </span>
                        </button>
                        <button
                            onClick={onEnter}
                            className="flex items-center gap-2 px-7 py-3.5 rounded-xl border border-white/[0.1] bg-white/[0.03] hover:bg-white/[0.06] hover:border-white/[0.16] text-zinc-300 font-medium text-sm transition-all duration-200"
                        >
                            View docs inside →
                        </button>
                    </div>
                    <div
                        className="flex items-center gap-10 pt-4 border-t border-white/[0.05] w-full justify-center"
                    >
                        {[
                            <div
                                key={s["label"]}
                                className="flex flex-col items-center gap-0.5"
                            >
                                <span
                                    className="text-2xl font-bold text-white tracking-tight"
                                >
                                    {s["value"]}
                                </span>
                                <span
                                    className="text-[10px] text-zinc-600 uppercase tracking-[0.18em]"
                                >
                                    {s["label"]}
                                </span>
                            </div> for s in STATS
                        ]}
                    </div>
                </div>
            </section>
            <section className="relative z-10 px-8 pb-12 max-w-5xl mx-auto w-full">
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
                    <div
                        className="group p-5 rounded-2xl border border-white/[0.06] bg-white/[0.02] hover:bg-white/[0.04] hover:border-orange-500/20 transition-all duration-300 space-y-3"
                    >
                        <div
                            className="h-9 w-9 rounded-xl bg-orange-500/10 border border-orange-500/20 flex items-center justify-center text-orange-400 text-base group-hover:bg-orange-500/20 transition-colors"
                        >
                            ◈
                        </div>
                        <div className="space-y-1.5">
                            <h3 className="text-sm font-semibold text-white">
                                Validate and Format
                            </h3>
                            <p className="text-[12px] text-zinc-500 leading-relaxed">
                                Real-time syntax checking, validation, and auto-formatting keep your code clean and correct.
                            </p>
                        </div>
                    </div>
                    <div
                        className="group p-5 rounded-2xl border border-white/[0.06] bg-white/[0.02] hover:bg-white/[0.04] hover:border-orange-500/20 transition-all duration-300 space-y-3"
                    >
                        <div
                            className="h-9 w-9 rounded-xl bg-orange-500/10 border border-orange-500/20 flex items-center justify-center text-orange-400 text-base group-hover:bg-orange-500/20 transition-colors"
                        >
                            ▶
                        </div>
                        <div className="space-y-1.5">
                            <h3 className="text-sm font-semibold text-white">
                                Run and Execute
                            </h3>
                            <p className="text-[12px] text-zinc-500 leading-relaxed">
                                Execute Jac programs directly. Set entrypoints, configure timeouts, see output instantly.
                            </p>
                        </div>
                    </div>
                    <div
                        className="group p-5 rounded-2xl border border-white/[0.06] bg-white/[0.02] hover:bg-white/[0.04] hover:border-orange-500/20 transition-all duration-300 space-y-3"
                    >
                        <div
                            className="h-9 w-9 rounded-xl bg-orange-500/10 border border-orange-500/20 flex items-center justify-center text-orange-400 text-base group-hover:bg-orange-500/20 transition-colors"
                        >
                            ⇄
                        </div>
                        <div className="space-y-1.5">
                            <h3 className="text-sm font-semibold text-white">
                                Convert and Transpile
                            </h3>
                            <p className="text-[12px] text-zinc-500 leading-relaxed">
                                Bridge Python and Jac effortlessly. Transpile Jac to Python or JavaScript with one click.
                            </p>
                        </div>
                    </div>
                    <div
                        className="group p-5 rounded-2xl border border-white/[0.06] bg-white/[0.02] hover:bg-white/[0.04] hover:border-orange-500/20 transition-all duration-300 space-y-3"
                    >
                        <div
                            className="h-9 w-9 rounded-xl bg-orange-500/10 border border-orange-500/20 flex items-center justify-center text-orange-400 text-base group-hover:bg-orange-500/20 transition-colors"
                        >
                            ⬡
                        </div>
                        <div className="space-y-1.5">
                            <h3 className="text-sm font-semibold text-white">
                                Explore and Learn
                            </h3>
                            <p className="text-[12px] text-zinc-500 leading-relaxed">
                                Visualize AST trees, render graphs, and search documentation. Master Jac in one place.
                            </p>
                        </div>
                    </div>
                </div>
            </section>
            <section className="relative z-10 px-8 pb-16 max-w-5xl mx-auto w-full">
                <div
                    className="rounded-2xl border border-white/[0.05] bg-white/[0.01] p-6 space-y-4"
                >
                    <p
                        className="text-[10px] text-zinc-600 uppercase tracking-[0.22em] font-medium text-center"
                    >
                        All available tools
                    </p>
                    <div className="flex flex-wrap justify-center gap-2">
                        {[
                            <span
                                key={t}
                                className="px-3 py-1 text-[11px] rounded-full border border-white/[0.07] bg-white/[0.02] text-zinc-500 font-mono hover:text-zinc-300 hover:border-white/[0.15] transition-colors cursor-default"
                            >
                                {t}
                            </span> for t in TOOLS
                        ]}
                    </div>
                </div>
            </section>
            <footer
                className="relative z-10 border-t border-white/[0.04] px-8 py-5 flex items-center justify-between"
            >
                <div className="flex items-center gap-2">
                    <div
                        className="h-5 w-5 rounded-md bg-gradient-to-br from-orange-400 to-orange-600 flex items-center justify-center flex-shrink-0"
                    >
                        <span className="text-[9px] font-black text-white">J</span>
                    </div>
                    <span className="text-[11px] text-zinc-600">Jac MCP Studio</span>
                </div>
                <span className="text-[11px] text-zinc-700">
                    Built on the Jaseci platform
                </span>
            </footer>
        </div>;
}
