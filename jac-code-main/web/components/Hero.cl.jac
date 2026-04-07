import from .ui.button { Button }

def:pub Hero() -> JsxElement {
    has typed_count: int = 0;

    terminal_lines = [
        {"text": "$ jac-coder", "cls": "text-orange-400 font-bold"},
        {"text": "", "cls": "h-1 block"},
        {"text": "> Add a contact form with email validation", "cls": "text-white/90"},
        {"text": "", "cls": "h-1 block"},
        {"text": "  Scanning project...", "cls": "text-white/30"},
        {"text": "  ✓ Analyzed 12 files, 4 nodes, 3 walkers", "cls": "text-emerald-400/80"},
        {"text": "  ✓ Created components/ContactForm.cl.jac", "cls": "text-emerald-400/80"},
        {"text": "  ✓ Created server/contact.jac", "cls": "text-emerald-400/80"},
        {"text": "  ✓ Updated main.jac -- added route", "cls": "text-emerald-400/80"},
        {"text": "  ✓ All files pass jac_check -- 0 errors", "cls": "text-emerald-400/80"},
        {"text": "", "cls": "h-1 block"},
        {"text": "  3 files created, 1 modified, 0 errors.", "cls": "text-white/70 font-medium"}
    ];

    can with entry {
        typed_count = 1;
    }

    can with [typed_count] entry {
        if typed_count > 0 and typed_count < len(terminal_lines) {
            delay = 500 if typed_count < 3 else 180;
            def advance_line() -> None {
                typed_count = typed_count + 1;
            }
            globalThis.setTimeout(advance_line, delay);
        }
    }

    def handle_install_vsce() -> None {
        globalThis.open("https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jac-coder", "_blank");
    }

    def handle_get_started() -> None {
        el = globalThis.document.getElementById("getting-started");
        if el { el.scrollIntoView({"behavior": "smooth"}); }
    }

    return (
        <section className="relative min-h-screen flex items-center justify-center pt-28 pb-20 px-6 overflow-hidden">
            <div className="absolute inset-0 pointer-events-none">
                <div className="hero-gradient"></div>
            </div>

            <div className="relative max-w-6xl mx-auto w-full">
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-20 items-center">

                    <div className="space-y-7 animate-fade-in-up">
                        <div className="section-label">
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                            Now available — CLI + VS Code
                        </div>

                        <h1 className="text-[3.25rem] md:text-[4rem] lg:text-[4.75rem] font-extrabold leading-[1.05] tracking-[-0.03em]">
                            <span className="gradient-text-subtle">Stop fighting</span>
                            <br />
                            <span className="gradient-text-subtle">generic AI.</span>
                            <br />
                            <span className="gradient-text">Ship Jac.</span>
                        </h1>

                        <p className="text-white/50 text-base md:text-lg leading-relaxed max-w-md">
                            JacCoder understands your Jac codebase — nodes, walkers, graph architecture. It reads your AST, writes valid code, and validates every change.
                        </p>

                        <div className="flex flex-col sm:flex-row gap-3 pt-1">
                            <Button size="lg" onClick={handle_install_vsce} className="inline-flex items-center justify-center gap-2.5 h-12 px-7 rounded-xl text-[0.9375rem] font-semibold shadow-[0_0_24px_-4px_rgba(249,115,22,0.3)]">
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M17.583 2.603L9.88 8.71 5.83 5.612l-1.83.925v10.933l1.837.918 4.043-3.09 7.703 6.107 2.417-1.18V3.783l-2.417-1.18zM9.56 15.291l-3.606 2.764V5.952l3.606 2.764v6.575zm8.023 3.073l-6.205-4.907V10.55l6.205-4.907v12.72z"/>
                                </svg>
                                Install for VS Code
                            </Button>
                            <Button variant="outline" size="lg" onClick={handle_get_started} className="inline-flex items-center justify-center gap-2 h-12 px-7 rounded-xl text-[0.9375rem] font-semibold border-white/10 hover:border-white/20 hover:bg-white/[0.03]">
                                CLI Quickstart
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                                    <path d="M5 12h14M12 5l7 7-7 7"></path>
                                </svg>
                            </Button>
                        </div>
                    </div>

                    <div className="animate-fade-in-up animation-delay-300">
                        <div className="code-block rounded-2xl overflow-hidden terminal-glow">
                            <div className="flex items-center gap-1.5 px-4 py-3 border-b border-white/[0.04]">
                                <div className="w-2.5 h-2.5 rounded-full bg-white/10"></div>
                                <div className="w-2.5 h-2.5 rounded-full bg-white/10"></div>
                                <div className="w-2.5 h-2.5 rounded-full bg-white/10"></div>
                                <span className="ml-3 text-white/20 text-[0.6875rem] font-mono">jac-coder</span>
                            </div>
                            <div className="p-5 md:p-6 min-h-[300px] space-y-0.5">
                                {[
                                    <div key={str(i)} className={line["cls"] + " text-[0.8125rem] leading-relaxed"}>
                                        {line["text"] if line["text"] else " "}
                                    </div>
                                    for (i, line) in enumerate(terminal_lines[:typed_count])
                                ]}
                                {typed_count < len(terminal_lines) and (
                                    <span className="terminal-cursor"></span>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
