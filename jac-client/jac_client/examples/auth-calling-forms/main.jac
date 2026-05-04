cl import from '@jac/runtime' { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }


cl {
    def:pub app -> JsxElement {
        has username: str = "",
            password: str = "",
            status: str = "ready",
            logged_in: bool = False;

        can with entry {
            logged_in = jacIsLoggedIn();
        }

        def do_signup_old(_evt: MouseEvent) {
            async def run {
                status = "pending";
                try {
                    result = await jacSignup(username, password);
                    if result["success"] {
                        status = "signup_old_ok";
                    } else {
                        err = result["error"] if "error" in result else "unknown";
                        status = f"signup_old_fail:{err}";
                    }
                } except Exception as e {
                    status = f"signup_old_exc:{e}";
                }
                logged_in = jacIsLoggedIn();
            }
            run();
        }

        def do_signup_new(_evt: MouseEvent) {
            async def run {
                status = "pending";
                try {
                    result = await jacSignup(
                        [{"type": "username", "value": username}], password
                    );
                    if result["success"] {
                        status = "signup_new_ok";
                    } else {
                        err = result["error"] if "error" in result else "unknown";
                        status = f"signup_new_fail:{err}";
                    }
                } except Exception as e {
                    status = f"signup_new_exc:{e}";
                }
                logged_in = jacIsLoggedIn();
            }
            run();
        }

        def do_login_old(_evt: MouseEvent) {
            async def run {
                status = "pending";
                try {
                    ok = await jacLogin(username, password);
                    status = "login_old_ok" if ok else "login_old_fail";
                } except Exception as e {
                    status = f"login_old_exc:{e}";
                }
                logged_in = jacIsLoggedIn();
            }
            run();
        }

        def do_login_new(_evt: MouseEvent) {
            async def run {
                status = "pending";
                try {
                    ok = await jacLogin(
                        {"type": "username", "value": username}, password
                    );
                    status = "login_new_ok" if ok else "login_new_fail";
                } except Exception as e {
                    status = f"login_new_exc:{e}";
                }
                logged_in = jacIsLoggedIn();
            }
            run();
        }

        def do_logout(_evt: MouseEvent) {
            jacLogout();
            logged_in = jacIsLoggedIn();
            status = "logged_out";
        }

        return
            <div style={{"padding": "20px", "fontFamily": "sans-serif"}}>
                <h1>Auth Calling Forms Demo</h1>
                <p data-testid="logged-in">logged_in={str(logged_in)}</p>
                <div>
                    <input
                        type="text"
                        data-testid="username-input"
                        value={username}
                        onChange={lambda e: ChangeEvent { username = e.target.value;}}
                        placeholder="username"
                    />
                    <input
                        type="password"
                        data-testid="password-input"
                        value={password}
                        onChange={lambda e: ChangeEvent { password = e.target.value;}}
                        placeholder="password"
                    />
                </div>
                <div style={{"marginTop": "8px"}}>
                    <button data-testid="signup-old" onClick={do_signup_old}>
                        Signup (old)
                    </button>
                    <button data-testid="signup-new" onClick={do_signup_new}>
                        Signup (new)
                    </button>
                    <button data-testid="login-old" onClick={do_login_old}>
                        Login (old)
                    </button>
                    <button data-testid="login-new" onClick={do_login_new}>
                        Login (new)
                    </button>
                    <button data-testid="logout-btn" onClick={do_logout}>Logout</button>
                </div>
                <div
                    data-testid="status"
                    style={{
                        "marginTop": "16px",
                        "padding": "8px",
                        "background": "#eee"
                    }}
                >
                    {status}
                </div>
            </div>;
    }
}
