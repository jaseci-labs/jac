"""Admin dashboard shell: floating glass sidebar + content panel.

A modern "console" layout - two rounded glass panels floating over an
ambient-lit background (the orange corner glow lives in styles/main.css).
The sidebar carries a profile block, icon nav (implemented pages only -
placeholder stubs stay hidden), and a logout action. Each nav id maps to
a page in PAGE_ROUTES; pages render their own headers. Icons come from
lucide-react (declared in jac.toml [dependencies.npm]).
"""

cl {
    import from ...components.common.Alert { Alert }
    import from ...context.AuthContext { useAuth }
    import from ...context.AlertContext { useAlert }
    import from ...constants.categories { navGroups }
    import from "lucide-react" {
        Users,
        ShieldCheck,
        BarChart3,
        Cpu,
        Bot,
        Network,
        ScrollText,
        LogOut
    }

    # Import pages (implemented only)
    import from .users.UsersPage { UsersPage }
    import from .sso.SSOPage { SSOPage }
    import from .monitoring.MetricsPage { MetricsPage }
    import from .monitoring.LLMMetricsPage { LLMMetricsPage }
    import from .monitoring.LLMTracesPage { LLMTracesPage }
    import from .monitoring.TracesPage { TracesPage }
    import from .logs.LogsPage { LogsPage }

    # Nav item id -> page component. Keep in sync with navGroups.
    glob PAGE_ROUTES = {
             "users": UsersPage,
             "sso": SSOPage,
             "metrics": MetricsPage,
             "llm_metrics": LLMMetricsPage,
             "llm_traces": LLMTracesPage,
             "traces": TracesPage,
             "logs": LogsPage
         };

    """Lucide icon for a nav id. Inherits color via currentColor so it
    tints with the active/hover text state."""
    def navIcon(id: str) -> JsxElement {
        cls = "w-[18px] h-[18px] shrink-0";
        if id == "users" {
            return <Users className={cls}/>;
        }
        if id == "sso" {
            return <ShieldCheck className={cls}/>;
        }
        if id == "metrics" {
            return <BarChart3 className={cls}/>;
        }
        if id == "llm_metrics" {
            return <Cpu className={cls}/>;
        }
        if id == "llm_traces" {
            return <Bot className={cls}/>;
        }
        if id == "traces" {
            return <Network className={cls}/>;
        }
        if id == "logs" {
            return <ScrollText className={cls}/>;
        }
        return <Network className={cls}/>;
    }

    def:pub DashboardLayout -> JsxElement {
        has activeTab: str = "metrics";

        auth = useAuth();
        alert = useAlert();

        def makeHandler(tabId: str) -> any {
            return lambda e: any { activeTab = tabId; };
        }

        def renderContent -> JsxElement {
            PageComponent = PAGE_ROUTES[activeTab];
            if PageComponent {
                return <PageComponent/>;
            }
            return <div className="text-slate-500 text-sm">Page not found</div>;
        }

        uname = String(auth["currentUsername"] or "");
        initial = String(uname or "U").charAt(0).toUpperCase();

        return
            <div className="flex h-screen gap-3 p-3 text-slate-200">
                <aside
                    className="relative w-64 shrink-0 flex flex-col rounded-3xl border border-white/10 bg-slate-900/40 backdrop-blur-2xl overflow-hidden shadow-xl shadow-black/40"
                >
                    <div
                        className="pointer-events-none absolute inset-x-0 bottom-0 h-56 bg-gradient-to-t from-orange-500/10 to-transparent"
                    ></div>

                    <div className="relative px-4 pt-5 pb-4">
                        <div className="flex items-center gap-3">
                            <div
                                className="w-11 h-11 rounded-2xl bg-gradient-to-br from-orange-400 to-amber-600 flex items-center justify-center text-white text-base font-bold shadow-[0_0_22px_-4px_rgba(249,115,22,0.75)]"
                            >
                                {initial}
                            </div>
                            <div className="min-w-0">
                                <div className="text-sm font-semibold text-white truncate">
                                    {uname or "Admin"}
                                </div>
                                <div className="text-[11px] text-slate-500">Administrator</div>
                            </div>
                        </div>
                    </div>

                    <nav className="relative flex-1 overflow-y-auto px-3 pb-4 space-y-6">
                        {[
                            <div key={group["label"]}>
                                <div
                                    className="px-2 mb-2 text-[11px] font-semibold uppercase tracking-wider text-slate-600"
                                >
                                    {group["label"]}
                                </div>
                                <div className="space-y-1">
                                    {[
                                        <button
                                            key={item["id"]}
                                            onClick={makeHandler(item["id"])}
                                            className={"w-full flex items-center gap-3 px-3 py-2.5 text-sm rounded-2xl transition-all " + (
                                                activeTab == item["id"]
                                                and "bg-orange-500/15 text-orange-100 font-medium ring-1 ring-inset ring-orange-500/30 shadow-[0_0_18px_-6px_rgba(249,115,22,0.85)]"
                                                or "text-slate-400 hover:text-white hover:bg-white/[0.05]"
                                            )}
                                        >
                                            {navIcon(item["id"])}
                                            <span>{item["label"]}</span>
                                        </button> for item in group["items"]
                                    ]}
                                </div>
                            </div> for group in navGroups
                        ]}
                    </nav>

                    <div className="relative px-3 pb-4 pt-2 border-t border-white/[0.06]">
                        <button
                            onClick={auth["logout"]}
                            className="w-full flex items-center gap-3 px-3 py-2.5 text-sm rounded-2xl text-slate-400 hover:text-white hover:bg-white/[0.05] transition-all"
                        >
                            <LogOut className="w-[18px] h-[18px] shrink-0"/>
                            <span>Logout</span>
                        </button>
                    </div>
                </aside>

                <main
                    className="flex-1 min-w-0 flex flex-col rounded-3xl border border-white/10 bg-slate-900/30 backdrop-blur-xl overflow-hidden shadow-xl shadow-black/40"
                >
                    <Alert message={alert["message"]} type={alert["alertType"]}/>
                    <div className="flex-1 overflow-y-auto p-6">{renderContent()}</div>
                </main>
            </div>;
    }
}
