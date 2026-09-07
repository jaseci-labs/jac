import from "@jac/runtime" {
    jacSignup,
    jacLogin,
    jacLogout,
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage,
    __removeLocalStorage
}
import from core.jacyac.github.auth { github_enabled }
import from core.jacyac.github.login { github_login }

obj Session {
    has loggedIn: bool,
        checking: bool,
        signup: bool,
        username: str,
        password: str,
        error: str,
        busy: bool,
        githubEnabled: bool,
        githubLogin: Callable[[], None],
        setUsername: Callable[[str], None],
        setPassword: Callable[[str], None],
        toggleMode: Callable[[], None],
        submit: Callable[[], None],
        logout: Callable[[], None];
}

def:pub useSession -> Session {
    has loggedIn: bool = False,
        checking: bool = True,
        signup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        busy: bool = False,
        githubEnabled: bool = False;

    async def checkGithub {
        try {
            githubEnabled = await github_enabled();
        } except Exception {
            githubEnabled = False;
        }
    }
    async def githubLogin -> None {
        if busy {
            return;
        }
        busy = True;
        error = "";
        try {
            if await github_login() {
                loggedIn = True;
            }
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }

    can with entry {
        checkGithub();
        loggedIn = jacIsLoggedIn();
        checking = False;
    }

    async def submit -> None {
        if busy {
            return;
        }
        error = "";
        if not username.strip() or not password {
            error = "Please fill in all fields";
            return;
        }
        if signup and len(password) < 4 {
            error = "Password must be at least 4 characters";
            return;
        }
        busy = True;
        try {
            if signup {
                result = await jacSignup(username.strip(), password);
                if not result.success {
                    error = str(result.error or "Signup failed");
                    return;
                }
            }
            if await jacLogin(username.strip(), password) {
                __setLocalStorage("jacyac_username", username.strip());
                password = "";
                loggedIn = True;
            } else {
                error = "Account created. Please log in."
                    if signup
                    else "Invalid username or password";
                signup = False;
            }
        } except Exception {
            error = "Could not reach the server. Please try again.";
        } finally {
            busy = False;
        }
    }

    def logout {
        jacLogout();
        for key in [
            "jacyac_username",
            "lx_username",
            "socialize_username",
            "lx_activity_total",
            "lx_welcomed"
        ] {
            __removeLocalStorage(key);
        }
        loggedIn = False;
        username = "";
        password = "";
        error = "";
        signup = False;
    }

    return Session(
        loggedIn=loggedIn,
        checking=checking,
        signup=signup,
        username=username,
        password=password,
        error=error,
        busy=busy,
        githubEnabled=githubEnabled,
        githubLogin=githubLogin,
        setUsername=lambda (value: str) { username = value; },
        setPassword=lambda (value: str) { password = value; },
        toggleMode=lambda {
            signup = not signup;
            error = "";
        },
        submit=submit,
        logout=logout
    );
}

def:pub stored_username -> str {
    return __getLocalStorage("jacyac_username")
        or __getLocalStorage("lx_username")
        or __getLocalStorage("socialize_username")
        or "";
}
