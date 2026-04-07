"""Auth page — login and register tabs with Google/GitHub SSO."""
import from "@jac/runtime" { jacLogin, jacSignup, jacIsLoggedIn, useNavigate, Navigate }
import from ..components.ui.button { Button }
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.card { Card, CardContent }
import from ..components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from ..components.ui.alert { Alert }
import from ..components.ui.spinner { Spinner }
import from "..components.ui.password-input" { PasswordInput }
import from ..components.ui.separator { Separator }

"""Login and signup page at /auth."""
def:pub AuthPage() -> Any {
    has activeTab: str = "login";
    has username: str = "";
    has password: str = "";
    has confirmPassword: str = "";
    has errorMsg: str = "";
    has isLoading: bool = False;

    navigate = useNavigate();

    if jacIsLoggedIn() {
        return <Navigate to="/dashboard" replace={True} />;
    }

    def handleSSO(platform: str) -> None {
        baseUrl = globalThis.__JAC_API_BASE_URL__ or "";
        window.location.href = baseUrl + "/sso/" + platform + "/login";
    }

    async def handleLogin() -> None {
        if not username or not password {
            errorMsg = "Username and password are required";
            return;
        }
        isLoading = True;
        errorMsg = "";
        try {
            success = await jacLogin(username, password);
            if success {
                localStorage.setItem("jac_display_name", username);
                navigate("/dashboard");
            } else {
                errorMsg = "Invalid username or password";
            }
        } except Exception as e {
            errorMsg = "Login failed: " + String(e);
        }
        isLoading = False;
    }

    async def handleRegister() -> None {
        if not username or not password {
            errorMsg = "Username and password are required";
            return;
        }
        if password != confirmPassword {
            errorMsg = "Passwords do not match";
            return;
        }
        isLoading = True;
        errorMsg = "";
        try {
            result = await jacSignup(username, password);
            if result and result.success {
                localStorage.setItem("jac_display_name", username);
                navigate("/dashboard");
            } else {
                errorMsg = (result.message if result and result.message else "Registration failed");
            }
        } except Exception as e {
            errorMsg = "Registration failed: " + String(e);
        }
        isLoading = False;
    }

    return <div className="min-h-screen bg-background flex flex-col">

        <div className="flex justify-center px-6 pt-4">
            <div className="flex items-center justify-between w-full max-w-[860px] bg-white/[0.04] border border-white/[0.08] rounded-[100px] py-2 pr-2 pl-[18px]" style={{"backdropFilter": "blur(16px)"}}>
                <div className="flex items-center gap-2 cursor-pointer" onClick={lambda { navigate("/"); }}>
                    <img src="/static/assets/logo-builder.png" className="w-[26px] h-[26px] rounded-md" alt="logo" />
                    <div className="text-sm font-bold font-mono tracking-[-0.02em] leading-none">
                        <span className="text-primary">{"jac"}</span>
                        <span className="text-muted-foreground font-medium">{" builder"}</span>
                        <span className="text-muted-foreground font-medium">{" studio"}</span>
                    </div>
                </div>
                <Button
                    variant="ghost"
                    size="xs"
                    onClick={lambda { navigate("/"); }}
                    className="text-muted-foreground hover:text-foreground rounded-full"
                >
                    {"Back"}
                </Button>
            </div>
        </div>

        <div className="flex-1 flex items-center justify-center pt-10 pb-6 px-6">
            <div className="w-full max-w-[400px]">
                <div className="flex flex-col items-center gap-1 mb-6">
                    <span className="text-xl font-bold text-foreground tracking-tight">
                        {"Welcome back"}
                    </span>
                    <span className="text-sm text-muted-foreground">{"Sign in to save and manage your projects"}</span>
                </div>

                <Card className="border-border">
                    <CardContent>
                        <div className="flex flex-col gap-3 mb-4">
                            <Button
                                variant="outline"
                                className="w-full rounded-full"
                                disabled={isLoading}
                                onClick={lambda { handleSSO("google"); }}
                            >
                                <svg className="size-4 mr-2" viewBox="0 0 24 24">
                                    <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" />
                                    <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                                    <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                                    <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                                </svg>
                                {"Continue with Google"}
                            </Button>
                            <Button
                                variant="outline"
                                className="w-full rounded-full"
                                disabled={isLoading}
                                onClick={lambda { handleSSO("github"); }}
                            >
                                <svg className="size-4 mr-2" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" />
                                </svg>
                                {"Continue with GitHub"}
                            </Button>
                        </div>

                        <div className="flex items-center gap-3 mb-4">
                            <Separator className="flex-1" />
                            <span className="text-xs text-muted-foreground">{"or"}</span>
                            <Separator className="flex-1" />
                        </div>

                        <Tabs value={activeTab} onValueChange={lambda val: str { activeTab = val or "login"; }}>
                            <TabsList className="w-full mb-4">
                                <TabsTrigger value="login" className="flex-1">{"Sign In"}</TabsTrigger>
                                <TabsTrigger value="register" className="flex-1">{"Create Account"}</TabsTrigger>
                            </TabsList>

                            <TabsContent value="login">
                                <div className="flex flex-col gap-4">
                                    <div className="flex flex-col gap-2">
                                        <Label htmlFor="login-username">{"Username"}</Label>
                                        <Input
                                            id="login-username"
                                            placeholder="your-username"
                                            value={username}
                                            onChange={lambda e: Any { username = e.target.value; }}
                                            disabled={isLoading}
                                        />
                                    </div>
                                    <div className="flex flex-col gap-2">
                                        <Label htmlFor="login-password">{"Password"}</Label>
                                        <PasswordInput
                                            placeholder="Enter password"
                                            value={password}
                                            onChange={lambda e: Any { password = e.target.value; }}
                                            disabled={isLoading}
                                        />
                                    </div>
                                    {errorMsg and activeTab == "login" and <Alert variant="destructive">{errorMsg}</Alert>}
                                    <Button
                                        className="w-full mt-1 rounded-full"
                                        disabled={isLoading}
                                        onClick={lambda { handleLogin(); }}
                                    >
                                        {isLoading and <Spinner className="size-4" /> or None}
                                        {"Sign In"}
                                    </Button>
                                </div>
                            </TabsContent>

                            <TabsContent value="register">
                                <div className="flex flex-col gap-4">
                                    <div className="flex flex-col gap-2">
                                        <Label htmlFor="reg-username">{"Username"}</Label>
                                        <Input
                                            id="reg-username"
                                            placeholder="your-username"
                                            value={username}
                                            onChange={lambda e: Any { username = e.target.value; }}
                                            disabled={isLoading}
                                        />
                                    </div>
                                    <div className="flex flex-col gap-2">
                                        <Label htmlFor="reg-password">{"Password"}</Label>
                                        <PasswordInput
                                            placeholder="Enter password"
                                            value={password}
                                            onChange={lambda e: Any { password = e.target.value; }}
                                            disabled={isLoading}
                                        />
                                    </div>
                                    <div className="flex flex-col gap-2">
                                        <Label htmlFor="reg-confirm">{"Confirm Password"}</Label>
                                        <PasswordInput
                                            placeholder="Enter password"
                                            value={confirmPassword}
                                            onChange={lambda e: Any { confirmPassword = e.target.value; }}
                                            disabled={isLoading}
                                        />
                                    </div>
                                    {errorMsg and activeTab == "register" and <Alert variant="destructive">{errorMsg}</Alert>}
                                    <Button
                                        className="w-full mt-1 rounded-full"
                                        disabled={isLoading}
                                        onClick={lambda { handleRegister(); }}
                                    >
                                        {isLoading and <Spinner className="size-4" /> or None}
                                        {"Create Account"}
                                    </Button>
                                </div>
                            </TabsContent>
                        </Tabs>
                    </CardContent>
                </Card>

                <p className="text-xs text-muted-foreground text-center mt-5">
                    {"Or "}
                    <span
                        className="text-primary cursor-pointer underline"
                        onClick={lambda { navigate("/"); }}
                    >
                        {"try without signing up"}
                    </span>
                </p>

                <p className="text-xs text-muted-foreground/60 text-center mt-3 leading-relaxed">
                    {"By signing in, you agree to our "}
                    <span className="text-muted-foreground cursor-pointer hover:text-foreground underline" onClick={lambda { navigate("/terms"); }}>{"Terms and Conditions"}</span>
                    {" and "}
                    <span className="text-muted-foreground cursor-pointer hover:text-foreground underline" onClick={lambda { navigate("/privacy"); }}>{"Privacy Policy"}</span>
                    {"."}
                </p>
            </div>
        </div>

    </div>;
}
