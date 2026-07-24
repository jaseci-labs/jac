"""Admin dashboard shell: flat sidebar + content panel.

A clean, minimal two-column layout - a solid sidebar (hairline right
border, no blur or glow) beside the content area. The sidebar carries a
profile block, grouped nav (implemented pages only - placeholder stubs
stay hidden), a light/dark toggle, and logout. Each nav id maps to a
page in PAGE_ROUTES; pages render their own headers. Icons come from
lucide-react (declared in jac.toml [dependencies.npm]). Colors are
semantic tokens from styles/main.css so the shell adapts to both themes.
"""

import from "lucide-react" {
    Users,
    ShieldCheck,
    BarChart3,
    BrainCircuit,
    Bot,
    Workflow,
    Server,
    ScrollText,
    Stethoscope,
    Boxes,
    Network,
    KeyRound,
    LogOut,
    CircleUserRound,
    Sun,
    Moon
}

import from react { useEffect }
import from ...components.common.Alert { Alert }
import from ...context.AuthContext { useAuth }
import from ...context.AlertContext { useAlert }
import from ...constants.categories { navGroups }
import from ...hooks.useStorage { getStorage, setStorage }

# Import pages (implemented only)
import from .users.UsersPage { UsersPage }
import from .sso.SSOPage { SSOPage }
import from .monitoring.MetricsPage { MetricsPage }
import from .monitoring.LLMMetricsPage { LLMMetricsPage }
import from .monitoring.LLMTracesPage { LLMTracesPage }
import from .monitoring.ServicesPage { ServicesPage }
import from .monitoring.TracesPage { TracesPage }
import from .logs.LogsPage { LogsPage }
import from .ops.OpsPage { OpsPage }
import from .ops.DeployPage { DeployPage }
import from .ops.NetworkPage { NetworkPage }
import from .ops.PodEnvPage { PodEnvPage }

# Nav item id -> page component. Keep in sync with navGroups.
glob PAGE_ROUTES = {
         "users": UsersPage,
         "sso": SSOPage,
         "metrics": MetricsPage,
         "services": ServicesPage,
         "llm_metrics": LLMMetricsPage,
         "llm_traces": LLMTracesPage,
         "traces": TracesPage,
         "logs": LogsPage,
         "ops": OpsPage,
         "deploy": DeployPage,
         "network": NetworkPage,
         "podenv": PodEnvPage
     };

def:pub DashboardLayout -> JsxElement {
    has activeTab: str = "metrics",
        isLight: bool = False;

    auth = useAuth();
    alert = useAlert();

    def makeHandler(tabId: str) -> any {
        return lambda (e: any) { activeTab = tabId; };
    }

    # Flip the `.light` class on <html>; tokens in main.css do the rest.
    def applyThemeClass(light: bool) {
        htmlEl = globalThis.document.documentElement;
        if htmlEl {
            if light {
                htmlEl.classList.add("light");
            } else {
                htmlEl.classList.remove("light");
            }
        }
    }

    def toggleTheme(e: any) {
        newLight = not isLight;
        isLight = newLight;
        applyThemeClass(newLight);
        setStorage("jac-admin-theme", newLight and "light" or "dark");
    }

    # Restore the persisted theme once on mount.
    useEffect(
        lambda { if getStorage("jac-admin-theme") == "light" {
            isLight = True;
            applyThemeClass(True);
        }},
        []
    );

    def renderContent -> JsxElement {
        PageComponent = PAGE_ROUTES[activeTab];
        if PageComponent {
            return <PageComponent/>;
        }
        return <div className="text-muted text-sm">Page not found</div>;
    }

    # Icon-per-id as a plain dict of pre-built elements (NOT a
    # def -> JsxElement helper). A def returning JSX gets compiled as a
    # React component, so calling it positionally passes `id` as props
    # and every lookup fell through to the default - that's why every
    # nav item rendered the same icon. A dict lookup has no such trap.
    iconCls = "w-[17px] h-[17px] shrink-0";
    navIcons = {
        "users": <Users className={iconCls}/>,
        "sso": <ShieldCheck className={iconCls}/>,
        "metrics": <BarChart3 className={iconCls}/>,
        "services": <Server className={iconCls}/>,
        "llm_metrics": <BrainCircuit className={iconCls}/>,
        "llm_traces": <Bot className={iconCls}/>,
        "traces": <Workflow className={iconCls}/>,
        "logs": <ScrollText className={iconCls}/>,
        "ops": <Stethoscope className={iconCls}/>,
        "deploy": <Boxes className={iconCls}/>,
        "network": <Network className={iconCls}/>,
        "podenv": <KeyRound className={iconCls}/>
    };

    uname = String(auth["currentUsername"] or "");

    return
        <div className="flex h-screen bg-bg text-fg">
            <aside
                className="w-60 shrink-0 flex flex-col border-r border-line bg-surface"
            >
                <div className="h-14 px-4 flex items-center gap-3 border-b border-line">
                    <div
                        className="w-8 h-8 rounded-md bg-accent flex items-center justify-center text-accent-fg"
                    >
                        <CircleUserRound className="w-5 h-5"/>
                    </div>
                    <div className="min-w-0">
                        <div className="text-sm font-medium text-fg truncate">
                            {uname or "Admin"}
                        </div>
                        <div className="text-[11px] text-faint">Administrator</div>
                    </div>
                </div>
                <nav className="flex-1 overflow-y-auto px-2 py-3 space-y-5">
                    {[
                        <div key={group["label"]}>
                            <div
                                className="px-2 mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-faint"
                            >
                                {group["label"]}
                            </div>
                            <div className="space-y-0.5">
                                {[
                                    <button
                                        key={item["id"]}
                                        onClick={makeHandler(item["id"])}
                                        className={"w-full flex items-center gap-2.5 px-2.5 py-2 text-sm rounded-md transition-colors " + (
                                            activeTab == item["id"]
                                            and "bg-accent-weak text-accent font-medium"
                                            or "text-muted hover:text-fg hover:bg-surface-2"
                                        )}
                                    >
                                        {navIcons[item["id"]]
                                        or <Workflow className={iconCls}/>}
                                        <span>{item["label"]}</span>
                                    </button> for item in group["items"]
                                ]}
                            </div>
                        </div> for group in navGroups
                    ]}
                </nav>
                <div className="px-2 py-2 border-t border-line space-y-0.5">
                    <button
                        onClick={toggleTheme}
                        className="w-full flex items-center gap-2.5 px-2.5 py-2 text-sm rounded-md text-muted hover:text-fg hover:bg-surface-2 transition-colors"
                    >
                        {isLight
                        and <Moon className="w-[17px] h-[17px] shrink-0"/>
                        or <Sun className="w-[17px] h-[17px] shrink-0"/>}
                        <span>{isLight and "Dark mode" or "Light mode"}</span>
                    </button>
                    <button
                        onClick={auth["logout"]}
                        className="w-full flex items-center gap-2.5 px-2.5 py-2 text-sm rounded-md text-muted hover:text-fg hover:bg-surface-2 transition-colors"
                    >
                        <LogOut className="w-[17px] h-[17px] shrink-0"/>
                        <span>Logout</span>
                    </button>
                </div>
            </aside>
            <main className="flex-1 min-w-0 flex flex-col bg-bg">
                <Alert message={alert["message"]} type={alert["alertType"]}/>
                <div className="flex-1 overflow-y-auto p-6">{renderContent()}</div>
            </main>
        </div>;
}
