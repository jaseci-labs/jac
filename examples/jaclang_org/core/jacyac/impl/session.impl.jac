impl useSession -> Session {
    has loggedIn: bool = False,
        checking: bool = True,
        username: str = "",
        error: str = "",
        busy: bool = False;

    async def check {
        name = "";
        try {
            name = await signed_in_name();
        } except Exception {}
        username = name;
        loggedIn = name != "";
        checking = False;
    }

    async can with entry {
        await check();
    }

    async def login {
        if busy {
            return;
        }
        busy = True;
        error = "";
        try {
            if await sign_in() {
                await check();
            }
        } except RemoteRejected as e {
            error = e.detail;
        } except Exception {
            error = "Could not reach the server. Please try again.";
        } finally {
            busy = False;
        }
    }

    async def logout {
        try {
            await sign_out();
        } except Exception {}
        for key in ["lx_activity_total", "lx_welcomed"] {
            __removeLocalStorage(key);
        }
        loggedIn = False;
        username = "";
        error = "";
    }

    return Session(
        loggedIn=loggedIn,
        checking=checking,
        username=username,
        error=error,
        busy=busy,
        login=login,
        logout=logout,
    );
}
