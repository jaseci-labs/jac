cl import from "@jac-client/utils" {
    Link,
    useNavigate,
    jacLogin
}
cl {
    def:pub LoginPage -> any {
    has username: str = "";
    has password: str = "";
    has error: str = "";
    navigate = useNavigate();

    async def handleLogin(e: any) -> None {
        e.preventDefault();
        error = "";
        if not username or not password {
            error = "Please fill in all fields";
            return;
        }
        success = await jacLogin(username, password);
        if success {
            navigate("/");
        } else {
            error = "Invalid credentials";
        }
    }

    def handleUsernameChange(e: any) -> None {
        username = e.target.value;
    }

    def handlePasswordChange(e: any) -> None {
        password = e.target.value;
    }

    errorDisplay = None;
    if error {
        errorDisplay = <div
            style={{"color": "#dc2626", "fontSize": "14px", "marginBottom": "12px"}}
        >
            {error}
        </div>;
    }

    return <div
        style={{
            "minHeight": "calc(100vh - 56px)",
            "display": "flex",
            "alignItems": "center",
            "justifyContent": "center",
            "background": "#f5f5f5"
        }}
    >
        <div
            style={{
                "background": "#ffffff",
                "padding": "32px",
                "borderRadius": "8px",
                "width": "300px",
                "boxShadow": "0 2px 8px rgba(0,0,0,0.1)"
            }}
        >
            <h2
                style={{"marginBottom": "24px", "textAlign": "center"}}
            >
                Login
            </h2>
            <form
                onSubmit={handleLogin}
            >
                <input
                    type="text"
                    value={username}
                    onChange={handleUsernameChange}
                    placeholder="Username"
                    style={{
                        "width": "100%",
                        "padding": "10px",
                        "marginBottom": "12px",
                        "border": "1px solid #ddd",
                        "borderRadius": "4px",
                        "boxSizing": "border-box"
                    }}
                />
                <input
                    type="password"
                    value={password}
                    onChange={handlePasswordChange}
                    placeholder="Password"
                    style={{
                        "width": "100%",
                        "padding": "10px",
                        "marginBottom": "12px",
                        "border": "1px solid #ddd",
                        "borderRadius": "4px",
                        "boxSizing": "border-box"
                    }}
                />
                {errorDisplay}
                <button
                    type="submit"
                    style={{
                        "width": "100%",
                        "padding": "10px",
                        "background": "#3b82f6",
                        "color": "#ffffff",
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontWeight": "600"
                    }}
                >
                    Login
                </button>
            </form>
            <p
                style={{
                    "textAlign": "center",
                    "marginTop": "16px",
                    "fontSize": "14px"
                }}
            >
                Need an account?
                {" "}
                <Link to="/signup">
                    Sign up
                </Link>
            </p>
        </div>
    </div>;
}
}
