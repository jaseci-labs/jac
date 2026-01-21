cl import from "@jac-client/utils" { jacSignup }
cl import from ..auth.authLogic { validateCredentials }
cl import from ..components.Button { Button }
cl import from ..components.Card { Card }

cl {
    def:pub SignupPage() -> any {
        has username: str = "";
        has password: str = "";
        has error: str = "";

        async def handleSignup(e: any) -> None {
            e.preventDefault();

            msg = validateCredentials(username, password);
            if msg {
                error = msg;
                return;
            }

            result = await jacSignup(username, password);
            if not result["success"] {
                error = "Signup failed";
            }
        }

        return <div className="center">
            <Card title="Sign Up">
                <form onSubmit={handleSignup}>
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
                    {error and <div className="error">{error}</div>}
                    <Button label="Create Account" onClick={None} />
                </form>
            </Card>
        </div>;
    }
}
