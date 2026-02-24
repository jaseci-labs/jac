"""Admin dashboard layout with navigation and content routing."""

cl {
    import from ...components.layout.Header { Header }
    import from ...components.layout.CategoryTabs { CategoryTabs }
    import from ...components.layout.SubTabs { SubTabs }
    import from ...components.common.Alert { Alert }
    import from ...context.AuthContext { useAuth }
    import from ...context.AlertContext { useAlert }
    import from ...constants.categories { categories, subTabs }

    # Import pages
    import from .users.UsersPage { UsersPage }
    import from .sso.SSOPage { SSOPage }
    import from .placeholder.PlaceholderPage {
        SessionsPage,
        ApiKeysPage,
        GraphPage,
        StoragePage,
        CachePage,
        WalkersPage,
        JobsPage,
        WebhooksPage,
        MetricsPage,
        LogsPage,
        HealthPage,
        AlertsConfigPage,
        ConfigPage,
        EnvironmentPage,
        SecretsPage,
        RateLimitsPage,
        CorsPage,
        EmailPage,
        NotificationsPage,
        StorageProvidersPage,
        DatabasePage,
        DeploymentsPage,
        ScalingPage,
        PodsPage,
        ActivityPage,
        SecurityPage
    }

    # Page route map: category -> subtab -> component
    glob PAGE_ROUTES = {
             "auth": {
                 "users": UsersPage,
                 "sso": SSOPage,
                 "sessions": SessionsPage,
                 "apikeys": ApiKeysPage
             },
             "data": {"graph": GraphPage, "storage": StoragePage, "cache": CachePage},
             "ops": {
                 "walkers": WalkersPage,
                 "jobs": JobsPage,
                 "webhooks": WebhooksPage
             },
             "monitor": {
                 "metrics": MetricsPage,
                 "logs": LogsPage,
                 "health": HealthPage,
                 "alerts": AlertsConfigPage
             },
             "settings": {
                 "config": ConfigPage,
                 "environment": EnvironmentPage,
                 "secrets": SecretsPage,
                 "ratelimits": RateLimitsPage,
                 "cors": CorsPage
             },
             "integrations": {
                 "email": EmailPage,
                 "notifications": NotificationsPage,
                 "storage_providers": StorageProvidersPage,
                 "database": DatabasePage
             },
             "deploy": {
                 "deployments": DeploymentsPage,
                 "scaling": ScalingPage,
                 "pods": PodsPage
             },
             "audit": {"activity": ActivityPage, "security": SecurityPage}
         };

    def:pub DashboardLayout -> JsxElement {
        has activeCategory: str = "auth",
            activeSubTab: str = "users";

        auth = useAuth();
        alert = useAlert();

        currentSubTabs = subTabs[activeCategory];

        def handleCategoryChange(catId: str, defaultTab: str) -> None {
            activeCategory = catId;
            activeSubTab = defaultTab;
        }

        def handleSubTabChange(tabId: str) -> None {
            activeSubTab = tabId;
        }

        def renderContent -> JsxElement {
            categoryRoutes = PAGE_ROUTES[activeCategory];
            if categoryRoutes {
                PageComponent = categoryRoutes[activeSubTab];
                if PageComponent {
                    return
                        <PageComponent/>;
                }
            }
            return
                <div className="text-slate-500">
                    Page not found
                </div>;
        }

        return
            <div className="min-h-screen bg-slate-950">
                <header className="bg-slate-900 border-b border-slate-800">
                    <Header
                        username={auth["currentUsername"]}
                        onLogout={auth["logout"]}
                    />
                    <CategoryTabs
                        categories={categories}
                        activeCategory={activeCategory}
                        onCategoryChange={handleCategoryChange}
                    />
                    <SubTabs
                        tabs={currentSubTabs}
                        activeTab={activeSubTab}
                        onTabChange={handleSubTabChange}
                    />
                </header>
                <Alert message={alert["message"]} type={alert["alertType"]}/>
                <main className="p-4">
                    {renderContent()}
                </main>
            </div>;
    }
}
