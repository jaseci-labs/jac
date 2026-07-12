# One client app whose routes each cover a dropped-coverage area:
#   /       Home       -- reader/writer walkers (auto-cache) + UndefChildProbe
#                          (undefined-JSX render safety) + app_meta_data title
#   /auth   AuthForms  -- jacSignup/jacLogin in both old (string) and new
#                          (identity/credential) calling forms
#   /form   FormPage   -- JacForm + JacSchema validation
#
# Walkers live in this served module so the server registers them as
# endpoints; the same-file `cl` block calls them via `root spawn`. Two readers
# (no mutation -> is_writer=false) and one writer (`create_item` mutates Root
# via `++>` -> is_writer=true) -- the split is what the auto-cache test reads.
node Item {
    has text: str;
}

walker:pub create_item {
    has text: str;

    can create with Root entry {
        new_item = here ++> Item(text=self.text);
        report new_item;
    }
}

walker:pub ping_server {
    can ping with Root entry {
        report "pong from backend!";
    }
}

walker:pub get_server_message {
    can info with Root entry {
        report "hello from a basic walker!";
    }
}

cl {
    import from '@jac/runtime' {
        Router,
        Routes,
        Route,
        JacForm,
        JacSchema,
        jacSignup,
        jacLogin,
        jacLogout,
        jacIsLoggedIn
    }

    # Renders an undefined child (`props.maybe` is never passed) beside a marker.
    # If an undefined JSX child crashed render, the marker would never mount.
    def:pub UndefChildProbe(props: any) -> JsxElement {
        return
            <div data-testid="undef-child-probe" style={{"display": "none"}}>
                {props.maybe}
                <span data-testid="undef-child-probe-ok">ok</span>
            </div>;
    }

    def:pub Home -> JsxElement {
        has pingResult: str = "",
            serverMessage: str = "",
            lastItem: str = "";

        async def handlePing {
            result = root spawn ping_server();
            if result.reports and len(result.reports) > 0 {
                pingResult = str(result.reports[0]);
            }
        }

        async def loadServerMessage {
            result = root spawn get_server_message();
            if result.reports and len(result.reports) > 0 {
                serverMessage = str(result.reports[0]);
            }
        }

        async def handleCreateItem {
            result = root spawn create_item(text="sample item");
            if result.reports and len(result.reports) > 0 {
                lastItem = "created";
            }
        }

        async can with entry {
            await loadServerMessage();
        }

        return
            <div style={{"padding": "2rem", "fontFamily": "system-ui, sans-serif"}}>
                <UndefChildProbe/>
                <h1>Fullstack Base</h1>
                <span data-testid="build-meta" style={{"display": "none"}}>
                    {globalThis.APP_BUILD_TIME or "(unset)"}|{import.meta.env.VITE_APP_NAME
                    or "(unset)"}
                </span>
                <p data-testid="server-message">{serverMessage}</p>
                <button
                    data-testid="ping-btn"
                    onClick={lambda (e: any) { handlePing(); }}
                >
                    Ping Backend
                </button>
                <button
                    data-testid="create-btn"
                    onClick={lambda (e: any) { handleCreateItem(); }}
                >
                    Create Item
                </button>
                {pingResult and (<span data-testid="ping-result">{pingResult}</span>)}
                {lastItem and (<p data-testid="last-item">{lastItem}</p>)}
            </div>;
    }

    def:pub AuthForms -> JsxElement {
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
                <h1>Auth Calling Forms</h1>
                <p data-testid="logged-in">logged_in={str(logged_in)}</p>
                <input
                    type="text"
                    data-testid="username-input"
                    value={username}
                    onChange={lambda (e: ChangeEvent) { username = e.target.value; }}
                    placeholder="username"
                />
                <input
                    type="password"
                    data-testid="password-input"
                    value={password}
                    onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
                    placeholder="password"
                />
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
                <div data-testid="status">{status}</div>
            </div>;
    }

    def:pub FormPage -> JsxElement {
        schema = JacSchema(
            {
                emailField: JacSchema.string().email("Invalid email"),
                passwordField: JacSchema.string().min(
                    8, "Password must be at least 8 characters"
                ).regex(
                    RegExp("[A-Z]"),
                    "Password must contain at least one uppercase letter"
                )
            }
        );

        async def handleSubmit(data: dict) {
            window.__submitFired = True;
        }

        return
            <JacForm
                schema={schema}
                onSubmit={handleSubmit}
                field_config={{
                    "emailField": {
                        "label": "Email",
                        "type": "email",
                        "placeholder": "you@example.com"
                    },
                    "passwordField": {"label": "Password", "type": "password"}
                }}
                submitLabel="Submit"
            />;
    }

    def:pub app -> JsxElement {
        return
            <Router>
                <Routes>
                    <Route path="/" element={<Home/>}/>
                    <Route path="/auth" element={<AuthForms/>}/>
                    <Route path="/form" element={<FormPage/>}/>
                </Routes>
            </Router>;
    }
}
