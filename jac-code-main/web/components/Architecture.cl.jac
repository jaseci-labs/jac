def:pub Architecture() -> JsxElement {
    return (
        <section id="how-it-works" className="relative py-32 px-6 section-glow">
            <div className="max-w-4xl mx-auto">
                <div className="text-center mb-20">
                    <div className="section-label mx-auto mb-5 w-fit">How It Works</div>
                    <h2 className="text-4xl md:text-5xl font-bold tracking-[-0.02em] mb-5">
                        <span className="gradient-text-subtle">Prompt. Build. Ship.</span>
                    </h2>
                    <p className="text-white/40 text-base md:text-lg max-w-lg mx-auto leading-relaxed">
                        No configuration. No prompt engineering. Describe what you want.
                    </p>
                </div>

                <div className="relative">
                    <div className="hidden md:block absolute left-6 top-0 bottom-0 w-px timeline-line"></div>

                    <div className="space-y-0">
                        <div className="relative flex items-stretch gap-8 md:gap-12 pb-14">
                            <div className="flex flex-col items-center flex-shrink-0 w-12">
                                <div className="w-12 h-12 rounded-full glass flex items-center justify-center z-10 border-orange-500/15">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fb923c" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"></path>
                                    </svg>
                                </div>
                            </div>
                            <div className="flex-1 pt-1.5">
                                <span className="text-[0.6875rem] font-semibold text-orange-400/60 uppercase tracking-widest">Step 1</span>
                                <h3 className="text-xl font-semibold text-white mt-1 mb-2">You describe what you need</h3>
                                <p className="text-white/40 text-sm leading-relaxed mb-4">
                                    In plain English — a feature, a fix, a refactor. JacCoder works from your intent, not templates.
                                </p>
                                <div className="code-block px-4 py-3 rounded-lg inline-block">
                                    <code className="text-[0.8125rem] font-mono text-orange-300/50">
                                        "Add a notification system with graph-based read/unread tracking"
                                    </code>
                                </div>
                            </div>
                        </div>

                        <div className="relative flex items-stretch gap-8 md:gap-12 pb-14">
                            <div className="flex flex-col items-center flex-shrink-0 w-12">
                                <div className="w-12 h-12 rounded-full glass flex items-center justify-center z-10 border-amber-500/15">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fbbf24" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <circle cx="11" cy="11" r="8"></circle>
                                        <path d="M21 21l-4.35-4.35"></path>
                                    </svg>
                                </div>
                            </div>
                            <div className="flex-1 pt-1.5">
                                <span className="text-[0.6875rem] font-semibold text-amber-400/60 uppercase tracking-widest">Step 2</span>
                                <h3 className="text-xl font-semibold text-white mt-1 mb-2">JacCoder reads your codebase</h3>
                                <p className="text-white/40 text-sm leading-relaxed mb-4">
                                    Parses your AST to understand every node, walker, edge, and import — then plans the changes.
                                </p>
                                <div className="code-block px-4 py-3 rounded-lg inline-block">
                                    <code className="text-[0.8125rem] font-mono text-amber-300/50">
                                        analyze_project -> 12 nodes, 8 walkers, 3 edges
                                    </code>
                                </div>
                            </div>
                        </div>

                        <div className="relative flex items-stretch gap-8 md:gap-12">
                            <div className="flex flex-col items-center flex-shrink-0 w-12">
                                <div className="w-12 h-12 rounded-full glass flex items-center justify-center z-10 border-emerald-500/15">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#34d399" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M22 11.08V12a10 10 0 11-5.93-9.14"></path>
                                        <path d="M22 4L12 14.01l-3-3"></path>
                                    </svg>
                                </div>
                            </div>
                            <div className="flex-1 pt-1.5">
                                <span className="text-[0.6875rem] font-semibold text-emerald-400/60 uppercase tracking-widest">Step 3</span>
                                <h3 className="text-xl font-semibold text-white mt-1 mb-2">Code is written and validated</h3>
                                <p className="text-white/40 text-sm leading-relaxed mb-4">
                                    Files are created or edited, then type-checked. Errors are fixed before you see the result.
                                </p>
                                <div className="code-block px-4 py-3 rounded-lg inline-block">
                                    <code className="text-[0.8125rem] font-mono text-emerald-300/50">
                                        3 files created -> jac_check -> 0 errors -> done
                                    </code>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
