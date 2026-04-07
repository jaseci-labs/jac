"""Main frontend entry point for Jac IDE application."""
import from react { useEffect }
import from "@jac/runtime" { Router, Routes, Route, Outlet }
import from "sonner" { Toaster }

import from .pages.JacIDE { JacIDE }
import from .pages.AuthPage { AuthPage }
import from .pages.OAuthCallback { OAuthCallback }
import from .pages.GitHubConnectCallback { GitHubConnectCallback }
import from .pages.LandingPage { LandingPage }
import from .pages.DashboardPage { DashboardPage }
import from .pages.AgentPage { AgentPage }
import from .pages.TermsPage { TermsPage }
import from .pages.PrivacyPage { PrivacyPage }
import from .components.auth.AuthGuard { AuthGuard }
import from ".utils.monaco_initializer" { initializeMonacoGlobally }
import from .components.ui.tooltip { TooltipProvider }
import from .hooks.useTheme { useTheme }

import ".global.css";

"""App layout — wraps all pages with TooltipProvider and Toaster."""
def:pub AppLayout() -> Any {
    themeState = useTheme();
    currentTheme = themeState.resolvedTheme or "dark";
    return <TooltipProvider delayDuration={200}>
        <div>
            <Toaster position="top-right" theme={currentTheme} richColors={True} />
            <Outlet />
        </div>
    </TooltipProvider>;
}

"""Main app component with routing."""
def:pub app() -> Any {
    useEffect(lambda {
        async def initMonaco() -> None {
            try {
                await initializeMonacoGlobally();
            } except Exception {
            }
        }
        initMonaco();
    }, []);

    return <Router>
        <Routes>
            <Route element={<AppLayout />}>
                <Route path="/" element={<LandingPage />} />
                <Route path="/auth" element={<AuthPage />} />
                <Route path="/auth/callback" element={<OAuthCallback />} />
                <Route path="/auth/github-connect" element={<GitHubConnectCallback />} />
                <Route path="/terms" element={<TermsPage />} />
                <Route path="/privacy" element={<PrivacyPage />} />
                <Route path="/dashboard" element={<AuthGuard><DashboardPage /></AuthGuard>} />
                <Route path="/project/:projectId" element={<AuthGuard><JacIDE /></AuthGuard>} />
                <Route path="/agent" element={<AuthGuard><AgentPage /></AuthGuard>} />
            </Route>
        </Routes>
    </Router>;
}
