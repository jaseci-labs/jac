"""Admin dashboard layout with navigation and content routing."""

cl import from '...components.layout.Header' { Header }
cl import from '...components.layout.CategoryTabs' { CategoryTabs }
cl import from '...components.layout.SubTabs' { SubTabs }
cl import from '...components.common.Alert' { Alert }
cl import from '...context.AuthContext' { useAuth }
cl import from '...context.AlertContext' { useAlert }
cl import from '...constants.categories' { categories, subTabs }

# Import pages
cl import from '.users.UsersPage' { UsersPage }
cl import from '.sso.SSOPage' { SSOPage }
cl import from '.placeholder.PlaceholderPage' {
    SessionsPage, ApiKeysPage, GraphPage, StoragePage, CachePage,
    WalkersPage, JobsPage, WebhooksPage, MetricsPage, LogsPage,
    HealthPage, AlertsConfigPage, ConfigPage, EnvironmentPage,
    SecretsPage, RateLimitsPage, CorsPage, EmailPage, NotificationsPage,
    StorageProvidersPage, DatabasePage, DeploymentsPage, ScalingPage,
    PodsPage, ActivityPage, SecurityPage
}

cl {
    def:pub DashboardLayout() -> JsxElement {
        has activeCategory: str = "auth";
        has activeSubTab: str = "users";

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

        def renderContent() -> JsxElement {
            # Auth category
            if activeCategory == "auth" {
                if activeSubTab == "users" { return <UsersPage />; }
                if activeSubTab == "sso" { return <SSOPage />; }
                if activeSubTab == "sessions" { return <SessionsPage />; }
                if activeSubTab == "apikeys" { return <ApiKeysPage />; }
            }

            # Data category
            if activeCategory == "data" {
                if activeSubTab == "graph" { return <GraphPage />; }
                if activeSubTab == "storage" { return <StoragePage />; }
                if activeSubTab == "cache" { return <CachePage />; }
            }

            # Ops category
            if activeCategory == "ops" {
                if activeSubTab == "walkers" { return <WalkersPage />; }
                if activeSubTab == "jobs" { return <JobsPage />; }
                if activeSubTab == "webhooks" { return <WebhooksPage />; }
            }

            # Monitor category
            if activeCategory == "monitor" {
                if activeSubTab == "metrics" { return <MetricsPage />; }
                if activeSubTab == "logs" { return <LogsPage />; }
                if activeSubTab == "health" { return <HealthPage />; }
                if activeSubTab == "alerts" { return <AlertsConfigPage />; }
            }

            # Settings category
            if activeCategory == "settings" {
                if activeSubTab == "config" { return <ConfigPage />; }
                if activeSubTab == "environment" { return <EnvironmentPage />; }
                if activeSubTab == "secrets" { return <SecretsPage />; }
                if activeSubTab == "ratelimits" { return <RateLimitsPage />; }
                if activeSubTab == "cors" { return <CorsPage />; }
            }

            # Integrations category
            if activeCategory == "integrations" {
                if activeSubTab == "email" { return <EmailPage />; }
                if activeSubTab == "notifications" { return <NotificationsPage />; }
                if activeSubTab == "storage_providers" { return <StorageProvidersPage />; }
                if activeSubTab == "database" { return <DatabasePage />; }
            }

            # Deploy category
            if activeCategory == "deploy" {
                if activeSubTab == "deployments" { return <DeploymentsPage />; }
                if activeSubTab == "scaling" { return <ScalingPage />; }
                if activeSubTab == "pods" { return <PodsPage />; }
            }

            # Audit category
            if activeCategory == "audit" {
                if activeSubTab == "activity" { return <ActivityPage />; }
                if activeSubTab == "security" { return <SecurityPage />; }
            }

            return <div>Unknown page</div>;
        }

        return <div className="min-h-screen bg-slate-950">
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

            <Alert message={alert["message"]} type={alert["alertType"]} />

            <main className="p-4">
                {renderContent()}
            </main>
        </div>;
    }
}
