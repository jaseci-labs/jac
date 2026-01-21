cl import from "@jac-client/utils" { jacIsLoggedIn }
cl import from .pages.LoginPage { LoginPage }
cl import from .pages.SignupPage { SignupPage }
cl import from .pages.TodosPage { TodosPage }
cl import ".styles.css";

cl {
    def:pub app() -> any {
        has authTab: str = "login";  # "login" | "signup"

        if jacIsLoggedIn() {
            return
                <TodosPage />;
        }

        return
            <div>
                <div className="auth-tabs">
                    <button
                        className={(
                            "auth-tab active" if authTab == "login" else "auth-tab"
                        )}
                        onClick={lambda -> None { authTab = "login";}}
                    >
                        Login
                    </button>
                    <button
                        className={(
                            "auth-tab active" if authTab == "signup" else "auth-tab"
                        )}
                        onClick={lambda -> None { authTab = "signup";}}
                    >
                        Sign Up
                    </button>
                </div>
                {(<LoginPage />) if authTab == "login" else (<SignupPage />)}
            </div>;
    }
}
