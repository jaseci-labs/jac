"""JAC-Scale Admin Portal - Entry Point."""

cl import "./styles/main.css";

cl {
    import from react { useEffect }
    import from .components.common.Spinner { LoadingScreen }
    import from .context.AuthContext { AuthProvider, useAuth }
    import from .context.AlertContext { AlertProvider }
    import from .hooks.useStorage { getStorage }
    import from .pages.auth.LoginPage { LoginPage }
    import from .pages.auth.ResetPage { ResetPage }
    import from .pages.admin.DashboardLayout { DashboardLayout }

    def AppContent -> JsxElement {
        auth = useAuth();

        # Restore the saved theme app-wide (before any conditional return,
        # per hook rules) so login/reset honor it too, not just the shell.
        useEffect(
            lambda { if getStorage("jac-admin-theme") == "light" {
                globalThis.document.documentElement.classList.add("light");
            }},
            []
        );

        if auth["isLoading"] {
            return <LoadingScreen/>;
        }

        if auth["view"] == "login" {
            return <LoginPage/>;
        }

        if auth["view"] == "reset" {
            return <ResetPage/>;
        }

        return <DashboardLayout/>;
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
