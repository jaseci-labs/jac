import from .ui.button { Button }

def:pub Navbar() -> JsxElement {
    has scrolled: bool = False;
    has mobile_open: bool = False;

    can with entry {
        def handle_scroll() -> None {
            scrolled = globalThis.window.scrollY > 20;
        }
        globalThis.window.addEventListener("scroll", handle_scroll);
    }

    def scroll_to(id: str) -> None {
        el = globalThis.document.getElementById(id);
        if el { el.scrollIntoView({"behavior": "smooth"}); }
        mobile_open = False;
    }

    def nav_features() -> None { scroll_to("features"); }
    def nav_demo() -> None { scroll_to("see-it-in-action"); }
    def nav_how() -> None { scroll_to("how-it-works"); }
    def nav_getting_started() -> None { scroll_to("getting-started"); }
    def toggle_mobile() -> None { mobile_open = not mobile_open; }

    def handle_marketplace() -> None {
        globalThis.open("https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jac-coder", "_blank");
    }

    def handle_github() -> None {
        globalThis.open("https://github.com/Jaseci-Labs/jaseci", "_blank");
    }

    navbar_class = "fixed top-0 left-0 right-0 z-50 transition-all duration-300 " + (
        "navbar-blur bg-[#050507]/80 border-b border-white/[0.05]" if scrolled else "bg-transparent border-b border-transparent"
    );

    return (
        <nav className={navbar_class}>
            <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center">
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5">
                            <path d="M13 10V3L4 14h7v7l9-11h-7z"></path>
                        </svg>
                    </div>
                    <span className="text-base font-bold gradient-text">JacCoder</span>
                </div>

                <div className="hidden md:flex items-center gap-0.5">
                    <button onClick={nav_features} className="px-3.5 py-2 text-[0.8125rem] text-white/40 hover:text-white/80 transition-colors rounded-lg">Features</button>
                    <button onClick={nav_demo} className="px-3.5 py-2 text-[0.8125rem] text-white/40 hover:text-white/80 transition-colors rounded-lg">Demo</button>
                    <button onClick={nav_how} className="px-3.5 py-2 text-[0.8125rem] text-white/40 hover:text-white/80 transition-colors rounded-lg">How It Works</button>
                    <button onClick={nav_getting_started} className="px-3.5 py-2 text-[0.8125rem] text-white/40 hover:text-white/80 transition-colors rounded-lg">Get Started</button>
                </div>

                <div className="hidden md:flex items-center gap-2">
                    <button onClick={handle_github} className="p-2 text-white/30 hover:text-white/60 transition-colors">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                        </svg>
                    </button>
                    <Button size="sm" onClick={handle_marketplace} className="h-8 px-4 rounded-lg text-xs font-semibold gap-1.5">
                        Install
                    </Button>
                </div>

                <button onClick={toggle_mobile} className="md:hidden p-2 text-white/40 hover:text-white/70">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        {mobile_open and (
                            <path d="M18 6L6 18M6 6l12 12"></path>
                        ) or (
                            <path d="M4 6h16M4 12h16M4 18h16"></path>
                        )}
                    </svg>
                </button>
            </div>

            {mobile_open and (
                <div className="md:hidden px-6 pb-4 space-y-0.5 border-t border-white/[0.04] bg-[#050507]/90 navbar-blur">
                    <button onClick={nav_features} className="block w-full text-left px-3 py-2.5 text-sm text-white/50 hover:text-white/80 transition-colors">Features</button>
                    <button onClick={nav_demo} className="block w-full text-left px-3 py-2.5 text-sm text-white/50 hover:text-white/80 transition-colors">Demo</button>
                    <button onClick={nav_how} className="block w-full text-left px-3 py-2.5 text-sm text-white/50 hover:text-white/80 transition-colors">How It Works</button>
                    <button onClick={nav_getting_started} className="block w-full text-left px-3 py-2.5 text-sm text-white/50 hover:text-white/80 transition-colors">Get Started</button>
                    <div className="pt-2 flex gap-2">
                        <button onClick={handle_github} className="flex-1 h-9 flex items-center justify-center text-sm text-white/40 border border-white/[0.06] rounded-lg">GitHub</button>
                        <Button size="sm" onClick={handle_marketplace} className="flex-1 h-9 rounded-lg text-xs font-semibold">Install</Button>
                    </div>
                </div>
            )}
        </nav>
    );
}
