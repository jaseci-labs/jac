cl import from "@jac-client/utils" { jacLogin, jacIsLoggedIn }
cl import from ..auth.authLogic {
    validateCredentials,
    shouldShowError
}
cl import from ..components.Button { Button }
cl import from ..components.Card { Card }

cl {
    def:pub LoginPage() -> any {
        has username: str = "";
        has password: str = "";
        has error: str = "";

        async def handleLogin(e: any) -> None {
            e.preventDefault();

            msg = validateCredentials(username, password);
            if msg {
                error = msg;
                return;
            }

            success = await jacLogin(username, password);
            if not success {
                error = "Invalid credentials";
            }
        }

        if jacIsLoggedIn() {
            return <div className="center">Already logged in</div>;
        }

        return <div className="center">
            <Card title="Login">
                <form onSubmit={handleLogin}>
                    <input
                        className="input"
                        placeholder="Username"
                        value={username}
                        onChange={lambda e: any -> None { username = e.target.value; }}
                    />
                    <input
                        className="input"
                        type="password"
                        placeholder="Password"
                        value={password}
                        onChange={lambda e: any -> None { password = e.target.value; }}
                    />
                    {(<div className="error">{error}</div>) if shouldShowError(error) else None}
                    <Button label="Login" onClick={None} />
                </form>
            </Card>
        </div>;
    }
}
