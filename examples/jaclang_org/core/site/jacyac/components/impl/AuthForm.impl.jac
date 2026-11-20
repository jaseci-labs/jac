impl AuthForm(
    error: str, loading: bool, onSignIn: Callable[[], Coroutine[any, any, None]]
) -> JsxElement {
    return <div className="flex min-h-[calc(100vh-4rem)] w-full bg-background text-foreground">
        <div
            className="relative hidden flex-1 items-center justify-center overflow-hidden bg-gradient-to-br from-primary/20 via-background to-background lg:flex"
        >
            <div
                className="absolute -left-24 top-1/3 size-96 rounded-full bg-primary/30 blur-[120px]"
            />
            <div className="relative flex flex-col items-center gap-6 px-12 text-center">
                <img
                    src="/static/assets/jacyak-logo.svg"
                    className="size-28 drop-shadow-[0_0_40px_var(--primary)]"
                    alt="JacYac"
                />
                <div>
                    <div
                        className="font-display text-5xl font-black tracking-tight text-foreground"
                    >
                        JacYac
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
                        src="/static/assets/jacyak-logo.svg"
                        className="mb-2 size-12 lg:hidden"
                        alt="JacYac"
                    />
                    <CardTitle className="font-display text-2xl font-extrabold">
                        Welcome to JacYac
                    </CardTitle>
                    <CardDescription>Sign in to join the conversation</CardDescription>
                </CardHeader>
                <CardContent>
                    {
                        if error {
                            <div
                                className="mb-4 flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive"
                            ><AlertCircle size={16} /><span>{error}</span></div>
                        }
                    }
                    <Button
                        type="button"
                        className="w-full font-semibold"
                        disabled={loading}
                        onClick={onSignIn}
                    >{"Signing in..." if loading else "Sign in"}</Button>
                </CardContent>
            </Card>
        </div>
    </div>;
}
