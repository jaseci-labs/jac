"""Authentication form component for Little X."""

import from "lucide-react" { AlertCircle }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.field { Field, FieldLabel }
import from .ui.input { Input }
import from .ui.button { Button }

def:pub AuthForm(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: Callable[[ChangeEvent], None],
    onPasswordChange: Callable[[ChangeEvent], None],
    onSubmit: Callable[[FormEvent], None],
    onToggleMode: Callable[[], None],
) -> JsxElement {
    return
        <div className="flex min-h-screen w-full bg-background text-foreground">
            <div
                className="relative hidden flex-1 items-center justify-center overflow-hidden bg-gradient-to-br from-primary/20 via-background to-background lg:flex"
            >
                <div
                    className="absolute -left-24 top-1/3 size-96 rounded-full bg-primary/30 blur-[120px]"
                />
                <div
                    className="relative flex flex-col items-center gap-6 px-12 text-center"
                >
                    <img
                        src="/static/assets/littlex-logo.svg"
                        className="size-28 drop-shadow-[0_0_40px_var(--primary)]"
                        alt="little-x"
                    />
                    <div>
                        <div
                            className="font-display text-5xl font-black tracking-tight text-foreground"
                        >
                            LITTLE-X
                        </div>
                        <p className="mt-3 max-w-sm text-balance text-muted-foreground">
                            A decentralized social platform built with Jac. Share thoughts, follow people, join the conversation.
                        </p>
                    </div>
                </div>
            </div>
            <div className="flex flex-1 items-center justify-center p-6">
                <Card className="w-full max-w-sm border-border/60 shadow-xl">
                    <CardHeader className="items-center text-center">
                        <img
                            src="/static/assets/littlex-logo.svg"
                            className="mb-2 size-12 lg:hidden"
                            alt="little-x"
                        />
                        <CardTitle className="font-display text-2xl font-extrabold">
                            {"Create your account" if isSignup else "Welcome back"}
                        </CardTitle>
                        <CardDescription>
                            {"Join the conversation on Little-X"
                                if isSignup
                                else "Sign in to your Little-X account"}
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        {if error {
                            <div
                                className="mb-4 flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive"
                            >
                                <AlertCircle size={16}/>
                                <span>{error}</span>
                            </div>
                        }}
                        <form {onSubmit} className="flex flex-col gap-4">
                            <Field>
                                <FieldLabel htmlFor="lx-username">Username</FieldLabel>
                                <Input
                                    id="lx-username"
                                    type="text"
                                    placeholder="yourname"
                                    value={username}
                                    onChange={onUsernameChange}
                                    autoComplete="username"
                                />
                            </Field>
                            <Field>
                                <FieldLabel htmlFor="lx-password">Password</FieldLabel>
                                <Input
                                    id="lx-password"
                                    type="password"
                                    placeholder="••••••••"
                                    value={password}
                                    onChange={onPasswordChange}
                                    autoComplete={"new-password"
                                        if isSignup
                                        else "current-password"}
                                />
                            </Field>
                            <Button
                                type="submit"
                                className="mt-1 w-full font-semibold"
                                disabled={loading
                                or not username.strip()
                                or not password}
                            >
                                {(
                                    "Processing..."
                                        if loading
                                        else ("Sign Up" if isSignup else "Log In")
                                )}
                            </Button>
                        </form>
                        <div className="mt-5 text-center text-sm text-muted-foreground">
                            {(
                                "Already have an account? "
                                    if isSignup
                                    else "New to Little-X? "
                            )}
                            <button
                                type="button"
                                className="font-semibold text-primary hover:underline"
                                onClick={onToggleMode}
                            >
                                {"Log In" if isSignup else "Sign Up"}
                            </button>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </div>;
}
