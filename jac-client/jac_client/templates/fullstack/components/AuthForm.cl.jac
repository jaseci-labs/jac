"""Authentication form component for login/signup."""

def:pub AuthForm(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: ChangeEventHandler,
    onPasswordChange: ChangeEventHandler,
    onSubmit: FormEventHandler,
    onToggleMode: MouseEventHandler
) -> JsxElement {
    return
        <div
            style={{
                "maxWidth": "400px",
                "margin": "4rem auto",
                "padding": "2rem",
                "fontFamily": "system-ui, -apple-system, sans-serif",
                "backgroundColor": "#fff",
                "borderRadius": "12px",
                "boxShadow": "0 4px 6px rgba(0,0,0,0.1)"
            }}
        >
            <h1
                style={{
                    "marginBottom": "0.5rem",
                    "color": "#1a1a2e",
                    "textAlign": "center"
                }}
            >
                Jac Todo App
            </h1>
            <p
                style={{
                    "marginBottom": "1.5rem",
                    "color": "#666",
                    "textAlign": "center"
                }}
            >
                {("Create an account" if isSignup else "Sign in to your account")}
            </p>
            {(
                <div
                    style={{
                        "padding": "0.75rem",
                        "marginBottom": "1rem",
                        "backgroundColor": "#fee",
                        "color": "#c00",
                        "borderRadius": "6px",
                        "fontSize": "0.9rem"
                    }}
                >
                    {error}
                </div>
            )
                if error
                else None}
            <form onSubmit={onSubmit}>
                <input
                    type="text"
                    value={username}
                    onChange={onUsernameChange}
                    placeholder="Username"
                    style={{
                        "width": "100%",
                        "padding": "0.75rem 1rem",
                        "marginBottom": "0.75rem",
                        "fontSize": "1rem",
                        "border": "2px solid #e0e0e0",
                        "borderRadius": "8px",
                        "outline": "none",
                        "boxSizing": "border-box"
                    }}
                />
                <input
                    type="password"
                    value={password}
                    onChange={onPasswordChange}
                    placeholder="Password"
                    style={{
                        "width": "100%",
                        "padding": "0.75rem 1rem",
                        "marginBottom": "1rem",
                        "fontSize": "1rem",
                        "border": "2px solid #e0e0e0",
                        "borderRadius": "8px",
                        "outline": "none",
                        "boxSizing": "border-box"
                    }}
                />
                <button
                    type="submit"
                    disabled={loading}
                    style={{
                        "width": "100%",
                        "padding": "0.75rem",
                        "fontSize": "1rem",
                        "backgroundColor": ("#999" if loading else "#4CAF50"),
                        "color": "white",
                        "border": "none",
                        "borderRadius": "8px",
                        "cursor": ("not-allowed" if loading else "pointer"),
                        "marginBottom": "1rem"
                    }}
                >
                    {(
                        (
                            "Processing..."
                                if loading
                                else ("Sign Up" if isSignup else "Log In")
                        )
                    )}
                </button>
            </form>
            <p style={{"textAlign": "center", "color": "#666", "fontSize": "0.9rem"}}>
                {(
                    "Already have an account? "
                        if isSignup
                        else "Don't have an account? "
                )}
                <span
                    onClick={onToggleMode}
                    style={{
                        "color": "#4CAF50",
                        "cursor": "pointer",
                        "fontWeight": "bold"
                    }}
                >
                    {("Log In" if isSignup else "Sign Up")}
                </span>
            </p>
        </div>;
}
