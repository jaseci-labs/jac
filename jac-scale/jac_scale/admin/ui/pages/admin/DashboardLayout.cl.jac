"""Admin dashboard shell: left sidebar nav + content area.

Sidebar groups come from `navGroups` (implemented pages only - the
placeholder stubs are hidden until built). Each nav item id maps to a
page component in PAGE_ROUTES. Pages render their own headers, so the
shell stays minimal: brand, grouped nav, user/logout footer.
"""

cl {
    import from ...components.common.Alert { Alert }
    import from ...context.AuthContext { useAuth }
    import from ...context.AlertContext { useAlert }
    import from ...constants.categories { navGroups }

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

    def:pub DashboardLayout -> JsxElement {
        has activeTab: str = "users";

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

        uname = auth["currentUsername"] or "";
        initial = (uname or "U").charAt(0).toUpperCase();

        return
            <div className="flex h-screen bg-slate-950 text-slate-200">
                <aside
                    className="w-60 shrink-0 flex flex-col border-r border-white/[0.06] bg-slate-900/40"
                >
                    <div
                        className="h-14 flex items-center gap-2.5 px-5 border-b border-white/[0.06]"
                    >
                        <div
                            className="w-7 h-7 rounded-lg bg-gradient-to-br from-orange-500 to-amber-600 flex items-center justify-center text-white text-xs font-bold shadow-sm shadow-orange-500/30"
                        >
                            J
                        </div>
                        <span className="text-sm font-semibold text-white tracking-tight">
                            JAC Admin
                        </span>
                    </div>

                    <nav className="flex-1 overflow-y-auto px-3 py-5 space-y-6">
                        {[
                            <div key={group["label"]}>
                                <div
                                    className="px-2 mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-slate-600"
                                >
                                    {group["label"]}
                                </div>
                                <div className="space-y-0.5">
                                    {[
                                        <button
                                            key={item["id"]}
                                            onClick={makeHandler(item["id"])}
                                            className={"w-full flex items-center px-3 py-2 text-sm rounded-lg transition-colors " + (
                                                activeTab == item["id"]
                                                and "bg-orange-500/10 text-orange-300 font-medium"
                                                or "text-slate-400 hover:text-slate-100 hover:bg-white/[0.04]"
                                            )}
                                        >
                                            {item["label"]}
                                        </button> for item in group["items"]
                                    ]}
                                </div>
                            </div> for group in navGroups
                        ]}
                    </nav>

                    <div
                        className="border-t border-white/[0.06] p-3 flex items-center justify-between gap-2"
                    >
                        <div className="flex items-center gap-2 min-w-0">
                            <div
                                className="w-7 h-7 rounded-full bg-slate-700 flex items-center justify-center text-xs font-medium text-slate-100 shrink-0"
                            >
                                {initial}
                            </div>
                            <span className="text-sm text-slate-300 truncate">{uname}</span>
                        </div>
                        <button
                            onClick={auth["logout"]}
                            className="text-xs text-slate-500 hover:text-slate-200 transition-colors shrink-0"
                        >
                            Logout
                        </button>
                    </div>
                </aside>

                <div className="flex-1 flex flex-col min-w-0">
                    <Alert message={alert["message"]} type={alert["alertType"]}/>
                    <main className="flex-1 overflow-y-auto p-6">{renderContent()}</main>
                </div>
            </div>;
    }
}
