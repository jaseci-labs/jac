import from "@jac/runtime" {
    jacLogin,
    jacSignup,
    __getApiBaseUrl,
    jacLogout,
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage,
    __removeLocalStorage
}

obj Session {
    has loggedIn: bool,
        checking: bool,
        signup: bool,
        username: str,
        email: str,
        password: str,
        error: str,
        busy: bool,
        githubEnabled: bool,
        githubLogin: Callable[[], None],
        setUsername: Callable[[str], None],
        setEmail: Callable[[str], None],
        setPassword: Callable[[str], None],
        toggleMode: Callable[[], None],
        submit: Callable[[], None],
        logout: Callable[[], None];
}

def:pub useSession -> Session;

def:pub stored_username -> str;

async def account_handle(fallback: str) -> str;

impl stored_username -> str {
    return __getLocalStorage("jacyac_username")
        or __getLocalStorage("lx_username")
        or __getLocalStorage("socialize_username")
        or "";
}
