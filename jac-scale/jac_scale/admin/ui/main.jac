"""JAC-Scale Admin Portal - Entry Point."""

cl import "./styles/main.css";

cl import from '.components.common.Spinner' { LoadingScreen }
cl import from '.context.AuthContext' { AuthProvider, useAuth }
cl import from '.context.AlertContext' { AlertProvider }
cl import from '.pages.auth.LoginPage' { LoginPage }
cl import from '.pages.auth.ResetPage' { ResetPage }
cl import from '.pages.admin.DashboardLayout' { DashboardLayout }

cl {
    def AppContent() -> JsxElement {
        auth = useAuth();

        if auth["isLoading"] {
            return <LoadingScreen />;
        }

        if auth["view"] == "login" {
            return <LoginPage />;
        }

        if auth["view"] == "reset" {
            return <ResetPage />;
        }

        return <DashboardLayout />;
    }

    def:pub app() -> JsxElement {
        return <AuthProvider>
            <AlertProvider>
                <AppContent />
            </AlertProvider>
        </AuthProvider>;
    }
}
