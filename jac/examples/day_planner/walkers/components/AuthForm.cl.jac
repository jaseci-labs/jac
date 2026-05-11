"""Login / signup form -- owns its own form state.

Calls `onAuth()` after a successful login or signup so the parent can
flip the app into its logged-in state.
"""

import from "@jac/runtime" { jacLogin, jacSignup }

def:pub AuthForm(onAuth: Callable[[], None]) -> JsxElement {
    has isSignup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False;

    async def handleLogin {
        error = "";
        if not username.strip() or not password {
            error = "Please fill in all fields";
            return;
        }
        loading = True;
        success = await jacLogin(username, password);
        loading = False;
        if success {
            onAuth();
        } else {
            error = "Invalid username or password";
        }
    }

    async def handleSignup {
        error = "";
        if not username.strip() or not password {
            error = "Please fill in all fields";
            return;
        }
        if len(password) < 4 {
            error = "Password must be at least 4 characters";
            return;
        }
        loading = True;
        result = await jacSignup(username, password);
        if result["success"] {
            # /user/register creates the account but does not return a
            # session token; sign in immediately to establish one.
            logged_in = await jacLogin(username, password);
            loading = False;
            if logged_in {
                onAuth();
            } else {
                error = "Account created but sign-in failed";
            }
        } else {
            loading = False;
            error = str(result["error"]) if result["error"] else "Signup failed";
        }
    }

    async def handleSubmit(e: FormEvent) {
        e.preventDefault();
        if isSignup {
            await handleSignup();
        } else {
            await handleLogin();
        }
    }

    return
        <div class="auth-container">
            <div class="auth-card">
                <h1 class="auth-title">AI Day Planner</h1>
                <p class="auth-subtitle">
                    {("Create your account" if isSignup else "Welcome back")}
                </p>
                {(<div class="auth-error">{error}</div>) if error else None}
                <form onSubmit={handleSubmit}>
                    <div class="form-field">
                        <label class="form-label">Username</label>
                        <input
                            type="text"
                            value={username}
                            onChange={lambda e: ChangeEvent { username = e.target.value; }}
                            placeholder="Enter username"
                            class="auth-input"
                        />
                    </div>
                    <div class="form-field">
                        <label class="form-label">Password</label>
                        <input
                            type="password"
                            value={password}
                            onChange={lambda e: ChangeEvent { password = e.target.value; }}
                            placeholder="Enter password"
                            class="auth-input"
                        />
                    </div>
                    <button type="submit" disabled={loading} class="auth-submit">
                        {(
                            "Processing..."
                                if loading
                                else ("Create Account" if isSignup else "Sign In")
                        )}
                    </button>
                </form>
                <div class="auth-toggle">
                    <span class="auth-toggle-text">
                        {(
                            "Already have an account? "
                                if isSignup
                                else "Don't have an account? "
                        )}
                    </span>
                    <button
                        type="button"
                        onClick={lambda {
                            isSignup = not isSignup;
                            error = "";
                        }}
                        class="auth-toggle-btn"
                    >
                        {("Sign In" if isSignup else "Sign Up")}
                    </button>
                </div>
            </div>
        </div>;
}
