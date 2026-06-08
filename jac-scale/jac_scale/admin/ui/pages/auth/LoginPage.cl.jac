"""Login page component."""

cl {
    import from ...components.common.Button { Button }
    import from ...components.common.Input { Input }
    import from ...components.common.Alert { InlineAlert }
    import from ...context.AuthContext { useAuth }
    def:pub LoginPage -> JsxElement {
        has loginUsername: str = "",
            loginPassword: str = "",
            loginError: str = "";

        auth = useAuth();

        async def handleLogin(e: any) {
            e.preventDefault();
            loginError = "";
            result = await auth["login"](loginUsername, loginPassword);
            if not result["ok"] {
                loginError = result["error"];
            }
        }

        return
            <div className="min-h-screen bg-bg flex items-center justify-center p-4">
                <div className="w-full max-w-sm">
                    <div className="text-center mb-8">
                        <h1 className="text-xl font-semibold text-fg tracking-tight">
                            JAC Admin
                        </h1>
                        <p className="text-muted text-sm mt-1">Sign in to continue</p>
                    </div>
                    <div
                        className="bg-surface border border-line rounded-lg p-6 shadow-sm"
                    >
                        <InlineAlert message={loginError} type="error"/>
                        <form onSubmit={handleLogin}>
                            <Input
                                label="Username"
                                type="text"
                                value={loginUsername}
                                onChange={lambda e: any { loginUsername = e.target.value; }}
                                placeholder="admin"
                                className="mb-4"
                            />
                            <Input
                                label="Password"
                                type="password"
                                value={loginPassword}
                                onChange={lambda e: any { loginPassword = e.target.value; }}
                                placeholder="Enter password"
                                className="mb-5"
                            />
                            <Button type="submit" className="w-full">Sign In</Button>
                        </form>
                    </div>
                </div>
            </div>;
    }
}
