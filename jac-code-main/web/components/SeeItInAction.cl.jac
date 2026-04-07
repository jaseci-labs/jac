def:pub SeeItInAction() -> JsxElement {
    has active_tab: str = "vscode";

    def set_vscode() -> None { active_tab = "vscode"; }
    def set_cli() -> None { active_tab = "cli"; }

    cli_lines = [
        {"text": "$ jac-coder", "cls": "text-orange-400 font-bold"},
        {"text": "JacCoder v1.0", "cls": "text-white/20"},
        {"text": "", "cls": "h-1 block"},
        {"text": "> Build a REST API for user profiles with graph persistence", "cls": "text-white/80"},
        {"text": "", "cls": "h-1 block"},
        {"text": "  ✓ think -- Planning node/walker structure", "cls": "text-white/25"},
        {"text": "  ✓ analyze_project -- Found 8 nodes, 5 walkers", "cls": "text-white/25"},
        {"text": "  ✓ jac_docs -- Graph persistence patterns", "cls": "text-white/25"},
        {"text": "  ✓ spawn_agent(worker) -- Writing backend", "cls": "text-white/25"},
        {"text": "", "cls": "h-0.5 block"},
        {"text": "    ✓ write_code -- server/models/user.jac", "cls": "text-emerald-400/70"},
        {"text": "    ✓ write_code -- server/walkers/user_api.jac", "cls": "text-emerald-400/70"},
        {"text": "    ✓ edit_code  -- server/main.jac", "cls": "text-emerald-400/70"},
        {"text": "    ✓ validate_project -- 0 errors", "cls": "text-emerald-400/70"},
        {"text": "", "cls": "h-1 block"},
        {"text": "  Created 2 files, modified 1. Ready to jac run.", "cls": "text-white/60 font-medium"}
    ];

    vscode_lines = [
        {"text": "  JacCoder", "cls": "text-orange-400/80 font-semibold text-xs tracking-wide uppercase"},
        {"text": "", "cls": "h-2 block"},
        {"text": "  You", "cls": "text-white/25 text-xs"},
        {"text": "  Add dark mode toggle to the settings page", "cls": "text-white/80 text-sm"},
        {"text": "", "cls": "h-3 block"},
        {"text": "  JacCoder", "cls": "text-white/25 text-xs"},
        {"text": "  I'll check your current component structure first.", "cls": "text-white/50 text-sm"},
        {"text": "", "cls": "h-2 block"},
        {"text": "  ✓ Analyzed Settings.cl.jac", "cls": "text-emerald-400/70 text-sm"},
        {"text": "  ✓ Created ThemeToggle.cl.jac", "cls": "text-emerald-400/70 text-sm"},
        {"text": "  ✓ Updated Settings.cl.jac", "cls": "text-emerald-400/70 text-sm"},
        {"text": "  ✓ Updated global.css", "cls": "text-emerald-400/70 text-sm"},
        {"text": "  ✓ All files pass jac_check", "cls": "text-emerald-400/70 text-sm"},
        {"text": "", "cls": "h-2 block"},
        {"text": "  Done — toggle added with system preference detection.", "cls": "text-white/60 font-medium text-sm"}
    ];

    active_lines = vscode_lines if active_tab == "vscode" else cli_lines;

    return (
        <section id="see-it-in-action" className="relative py-32 px-6 section-glow">
            <div className="max-w-5xl mx-auto">
                <div className="text-center mb-14">
                    <div className="section-label mx-auto mb-5 w-fit">Product</div>
                    <h2 className="text-4xl md:text-5xl font-bold tracking-[-0.02em] mb-5">
                        <span className="gradient-text-subtle">See it in action</span>
                    </h2>
                    <p className="text-white/40 text-base md:text-lg max-w-lg mx-auto leading-relaxed">
                        Use JacCoder inside VS Code or from your terminal.
                    </p>
                </div>

                <div className="glass rounded-xl p-1 w-fit mx-auto mb-8">
                    <div className="flex items-center gap-1">
                        <button onClick={set_vscode} className={"tab-btn " + ("tab-btn-active" if active_tab == "vscode" else "")}>
                            <span className="flex items-center gap-2">
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M17.583 2.603L9.88 8.71 5.83 5.612l-1.83.925v10.933l1.837.918 4.043-3.09 7.703 6.107 2.417-1.18V3.783l-2.417-1.18zM9.56 15.291l-3.606 2.764V5.952l3.606 2.764v6.575zm8.023 3.073l-6.205-4.907V10.55l6.205-4.907v12.72z"/>
                                </svg>
                                VS Code
                            </span>
                        </button>
                        <button onClick={set_cli} className={"tab-btn " + ("tab-btn-active" if active_tab == "cli" else "")}>
                            <span className="flex items-center gap-2">
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <path d="M8 9l3 3-3 3m5 0h3"></path>
                                    <rect x="3" y="4" width="18" height="16" rx="2"></rect>
                                </svg>
                                Terminal
                            </span>
                        </button>
                    </div>
                </div>

                <div className="code-block rounded-2xl overflow-hidden terminal-glow">
                    <div className="flex items-center gap-1.5 px-4 py-3 border-b border-white/[0.04]">
                        <div className="w-2.5 h-2.5 rounded-full bg-white/10"></div>
                        <div className="w-2.5 h-2.5 rounded-full bg-white/10"></div>
                        <div className="w-2.5 h-2.5 rounded-full bg-white/10"></div>
                        <span className="ml-3 text-white/20 text-[0.6875rem] font-mono">
                            {active_tab == "vscode" and "VS Code - JacCoder Panel" or "jac-coder session"}
                        </span>
                    </div>
                    <div className="p-5 md:p-7 space-y-0.5 min-h-[380px]">
                        {[
                            <div key={str(i)} className={line["cls"] + " font-mono"}>
                                {line["text"] if line["text"] else " "}
                            </div>
                            for (i, line) in enumerate(active_lines)
                        ]}
                    </div>
                </div>
            </div>
        </section>
    );
}
