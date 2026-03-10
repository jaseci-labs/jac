"""JAC-Scale Admin Portal - Entry Point."""

cl import "./styles/main.css";

cl {
    import from .components.common.Spinner { LoadingScreen }
    import from .context.AuthContext { AuthProvider, useAuth }
    import from .context.AlertContext { AlertProvider }
    import from .pages.auth.LoginPage { LoginPage }
    import from .pages.auth.ResetPage { ResetPage }
    import from .pages.admin.DashboardLayout { DashboardLayout }

    def AppContent -> JsxElement {
        auth = useAuth();

        if auth["isLoading"] {
            return
                <LoadingScreen/>;
        }

        if auth["view"] == "login" {
            return
                <LoginPage/>;
        }

        if auth["view"] == "reset" {
            return
                <ResetPage/>;
        }

        return
            <DashboardLayout/>;
    }

    def:pub app -> JsxElement {
        return
            <AuthProvider>
                <AlertProvider>
                    <AppContent/>
                </AlertProvider>
            </AuthProvider>;
    }
}
