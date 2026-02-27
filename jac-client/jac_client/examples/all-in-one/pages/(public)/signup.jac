cl import from "@jac/runtime" { Link, useNavigate, jacSignup }

cl {
    def:pub page -> JsxElement {
        has username: str = "",
            password: str = "",
            error: str = "";

        navigate = useNavigate();

        async def handleSignup(e: any) -> None {
            e.preventDefault();
            error = "";
            if not username or not password {
                error = "Please fill in all fields";
                return;
            }
            result = await jacSignup(username, password);
            if result["success"] {
                navigate("/");
            } else {
                error = result["error"] if result["error"] else "Signup failed";
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

        return
            <div
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
                    <h2 style={{"marginBottom": "24px", "textAlign": "center"}}>
                        Sign Up
                    </h2>
                    <form onSubmit={handleSignup}>
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
                            Sign Up
                        </button>
                    </form>
                    <p
                        style={{
                            "textAlign": "center",
                            "marginTop": "16px",
                            "fontSize": "14px"
                        }}
                    >
                        Have an account?
                        {" "}
                        <Link to="/login">
                            Login
                        </Link>
                    </p>
                </div>
            </div>;
    }
}
