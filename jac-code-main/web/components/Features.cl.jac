def:pub Features() -> JsxElement {
    return (
        <section id="features" className="relative py-32 px-6 section-glow">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-20">
                    <div className="section-label mx-auto mb-5 w-fit">Why JacCoder</div>
                    <h2 className="text-4xl md:text-5xl font-bold tracking-[-0.02em] mb-5">
                        <span className="gradient-text-subtle">Generic AI tools don't know Jac.</span>
                    </h2>
                    <p className="text-white/40 text-base md:text-lg max-w-xl mx-auto leading-relaxed">
                        Copilot hallucinates Jac syntax. JacCoder reads your compiler output and fixes its own mistakes.
                    </p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-6 gap-4">

                    <div className="glass glass-accent spot-card md:col-span-3 p-7 md:p-8">
                        <div className="relative z-[2]">
                            <div className="w-10 h-10 rounded-xl bg-orange-500/8 border border-orange-500/12 flex items-center justify-center mb-5">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fb923c" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
                                </svg>
                            </div>
                            <h3 className="text-lg font-semibold text-white mb-2">Understands your codebase</h3>
                            <p className="text-white/40 text-sm leading-relaxed">
                                Parses your AST — nodes, walkers, edges, imports — not just text. It knows your architecture before writing a single line.
                            </p>
                        </div>
                    </div>

                    <div className="glass glass-accent spot-card md:col-span-3 p-7 md:p-8">
                        <div className="relative z-[2]">
                            <div className="w-10 h-10 rounded-xl bg-emerald-500/8 border border-emerald-500/12 flex items-center justify-center mb-5">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#34d399" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                </svg>
                            </div>
                            <h3 className="text-lg font-semibold text-white mb-2">Writes valid code</h3>
                            <p className="text-white/40 text-sm leading-relaxed">
                                Every file is type-checked after writing. Errors are caught and fixed in the same turn — no broken commits.
                            </p>
                        </div>
                    </div>

                    <div className="glass glass-accent spot-card md:col-span-4 p-7 md:p-8">
                        <div className="relative z-[2] flex items-start gap-5">
                            <div className="w-10 h-10 rounded-xl bg-amber-500/8 border border-amber-500/12 flex items-center justify-center flex-shrink-0">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fbbf24" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"></path>
                                </svg>
                            </div>
                            <div>
                                <h3 className="text-lg font-semibold text-white mb-2">Delegates complex work</h3>
                                <p className="text-white/40 text-sm leading-relaxed">
                                    Need a full feature across multiple files? JacCoder spawns focused sub-agents that read, write, and validate independently — then merges the results.
                                </p>
                            </div>
                        </div>
                    </div>

                    <div className="glass glass-accent spot-card md:col-span-2 p-7 md:p-8 flex flex-col justify-between">
                        <div className="relative z-[2]">
                            <div className="w-10 h-10 rounded-xl bg-violet-500/8 border border-violet-500/12 flex items-center justify-center mb-5">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#a78bfa" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"></path>
                                </svg>
                            </div>
                            <h3 className="text-lg font-semibold text-white mb-2">Persistent memory</h3>
                            <p className="text-white/40 text-sm leading-relaxed">
                                Conventions and decisions persist across sessions.
                            </p>
                        </div>
                    </div>

                    <div className="glass glass-accent spot-card md:col-span-2 p-7 md:p-8">
                        <div className="relative z-[2]">
                            <div className="w-10 h-10 rounded-xl bg-sky-500/8 border border-sky-500/12 flex items-center justify-center mb-5">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                                </svg>
                            </div>
                            <h3 className="text-base font-semibold text-white mb-1.5">CLI + VS Code</h3>
                            <p className="text-white/35 text-sm leading-relaxed">
                                Same agent, same tools. Use it where you work.
                            </p>
                        </div>
                    </div>

                    <div className="glass glass-accent spot-card md:col-span-2 p-7 md:p-8">
                        <div className="relative z-[2]">
                            <div className="w-10 h-10 rounded-xl bg-orange-500/8 border border-orange-500/12 flex items-center justify-center mb-5">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fb923c" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M11 4a2 2 0 114 0v1a1 1 0 001 1h3a1 1 0 011 1v3a1 1 0 01-1 1h-1a2 2 0 100 4h1a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1v-1a2 2 0 10-4 0v1a1 1 0 01-1 1H7a1 1 0 01-1-1v-3a1 1 0 00-1-1H4a2 2 0 110-4h1a1 1 0 001-1V7a1 1 0 011-1h3a1 1 0 001-1V4z"></path>
                                </svg>
                            </div>
                            <h3 className="text-base font-semibold text-white mb-1.5">23 built-in tools</h3>
                            <p className="text-white/35 text-sm leading-relaxed">
                                Filesystem, git, web, jac_check, jac_docs, and more.
                            </p>
                        </div>
                    </div>

                    <div className="glass glass-accent spot-card md:col-span-2 p-7 md:p-8">
                        <div className="relative z-[2]">
                            <div className="w-10 h-10 rounded-xl bg-rose-500/8 border border-rose-500/12 flex items-center justify-center mb-5">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fb7185" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M9 3H5a2 2 0 00-2 2v4m6-6h10a2 2 0 012 2v4M9 3v18m0 0h10a2 2 0 002-2V9M9 21H5a2 2 0 01-2-2V9m0 0h18"></path>
                                </svg>
                            </div>
                            <h3 className="text-base font-semibold text-white mb-1.5">Smart context</h3>
                            <p className="text-white/35 text-sm leading-relaxed">
                                Never loses critical details mid-build. Compacts intelligently.
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
