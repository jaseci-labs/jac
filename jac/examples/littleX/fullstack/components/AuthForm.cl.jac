"""Authentication form component for Little X."""

def:pub AuthForm(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: any,
    onPasswordChange: any,
    onSubmit: any,
    onToggleMode: any,
) -> JsxElement {
    return
        <div className="lx-auth-root">
            <div className="lx-auth-left">
                <img
                    src="/static/assets/littlex-logo.svg"
                    className="lx-auth-logo-big"
                    alt="little-x"
                />
            </div>
            <div className="lx-auth-right">
                <div className="lx-auth-box">
                    <img
                        src="/static/assets/littlex-logo.svg"
                        className="lx-auth-mobile-logo"
                        alt="little-x"
                    />
                    <div className="lx-auth-heading">LITTLE-X</div>
                    <div className="lx-auth-sub">
                        {"Create your account and join the conversation"
                            if isSignup
                            else "Sign in to your account"}
                    </div>
                    {if error {
                        <div className="lx-auth-error">{error}</div>
                    }}
                    <form onSubmit={onSubmit} className="lx-auth-form-fields">
                        <input
                            className="lx-input"
                            type="text"
                            placeholder="Username"
                            value={username}
                            onChange={onUsernameChange}
                            autoComplete="username"
                        />
                        <input
                            className="lx-input"
                            type="password"
                            placeholder="Password"
                            value={password}
                            onChange={onPasswordChange}
                            autoComplete={"new-password"
                                if isSignup
                                else "current-password"}
                        />
                        <button
                            className="lx-auth-btn"
                            type="submit"
                            disabled={loading}
                        >
                            {(
                                "Processing..."
                                    if loading
                                    else ("Sign Up" if isSignup else "Log In")
                            )}
                        </button>
                    </form>
                    <div className="lx-auth-toggle">
                        {(
                            "Already have an account? "
                                if isSignup
                                else "New to Little-X? "
                        )}
                        <span className="lx-auth-toggle-link" onClick={onToggleMode}>
                            {"Log In" if isSignup else "Sign Up"}
                        </span>
                    </div>
                </div>
            </div>
        </div>;
}
