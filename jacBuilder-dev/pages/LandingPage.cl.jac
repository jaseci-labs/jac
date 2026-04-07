"""Landing page — public entry point for Jac Builder Studio."""
import from "@jac/runtime" { jacLogin, jacSignup, jacIsLoggedIn, useNavigate, Navigate }
import from ..components.ui.button { Button }
import from ..components.ui.spinner { Spinner }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowRight01Icon }

"""Public landing page — hero section with guest play and sign-in CTA."""
def:pub LandingPage() -> Any {
    navigate = useNavigate();
    has isStarting: bool = False;
    has startError: str = "";

    if jacIsLoggedIn() {
        return <Navigate to="/dashboard" replace={True} />;
    }

    async def handleGuestPlay() -> None {
        isStarting = True;
        startError = "";
        try {
            storedRaw = localStorage.getItem("jac_guest_creds");
            if storedRaw {
                try {
                    creds = JSON.parse(storedRaw);
                    ok = await jacLogin(creds.u, creds.p);
                    if ok {
                        navigate("/dashboard");
                        return;
                    }
                } except Exception {
                    localStorage.removeItem("jac_guest_creds");
                }
            }
            guestUser = "g" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
            guestPass = Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
            localStorage.setItem("jac_guest_creds", JSON.stringify({"u": guestUser, "p": guestPass}));
            result = await jacSignup(guestUser, guestPass);
            if result and result.success {
                navigate("/dashboard");
            } else {
                startError = "Could not start session. Please try signing in.";
                localStorage.removeItem("jac_guest_creds");
            }
        } except Exception as e {
            startError = "Something went wrong: " + String(e);
        }
        isStarting = False;
    }

    return <div className="min-h-screen bg-background flex flex-col relative overflow-hidden">

        <div className="absolute top-[15%] left-1/2 -translate-x-1/2 w-[720px] h-[520px] pointer-events-none z-0" style={{"background": "radial-gradient(ellipse at center, rgba(249,115,22,0.13) 0%, rgba(249,115,22,0.04) 45%, transparent 72%)"}} />

        <div className="flex justify-center px-6 pt-4 relative z-10">
            <div className="flex items-center justify-between w-full max-w-[860px] bg-muted/50 border border-border rounded-[100px] py-2 pr-2 pl-[18px]" style={{"backdropFilter": "blur(16px)"}}>
                <div className="flex items-center gap-2 cursor-pointer" onClick={lambda { navigate("/"); }}>
                    <img src="/static/assets/logo-builder.png" className="w-[26px] h-[26px] rounded-md" alt="logo" />
                    <div className="text-sm font-bold font-mono tracking-[-0.02em] leading-none">
                        <span className="text-primary">{"jac"}</span>
                        <span className="text-muted-foreground font-medium">{" builder"}</span>
                        <span className="text-muted-foreground font-medium">{" studio"}</span>
                    </div>
                </div>
                <div className="flex items-center gap-1.5">
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={lambda { navigate("/auth"); }}
                        className="text-muted-foreground hover:text-foreground rounded-full"
                    >
                        {"Sign In"}
                    </Button>
                    <Button
                        size="sm"
                        disabled={isStarting}
                        onClick={lambda { handleGuestPlay(); }}
                        className="rounded-full font-semibold"
                    >
                        {isStarting and <Spinner className="size-3.5" /> or None}
                        {"Get Started"}
                    </Button>
                </div>
            </div>
        </div>

        <div className="flex-1 flex items-center justify-center relative z-[1]" style={{"padding": "56px 24px 48px"}}>
            <div className="flex flex-col items-center max-w-[820px] w-full">

                <div className="inline-flex items-center gap-2 bg-muted/50 border border-border rounded-[100px] px-4 py-[5px] mb-8">
                    <div className="w-[7px] h-[7px] rounded-full bg-success flex-shrink-0 animate-[landing-pulse_2.2s_ease-in-out_infinite]" style={{"boxShadow": "0 0 6px rgba(34,197,94,0.7)"}} />
                    <span className="text-xs text-muted-foreground font-medium">{"Now in Public Beta"}</span>
                </div>

                <div className="text-center mb-[22px]" style={{"letterSpacing": "-0.03em", "fontWeight": 800, "lineHeight": "1.05"}}>
                    <div className="text-foreground font-extrabold" style={{"fontSize": "clamp(2.8rem, 8vw, 5.5rem)", "lineHeight": "1.05", "letterSpacing": "-0.03em"}}>{"Build Jac apps."}</div>
                    <div className="text-muted-foreground/50 font-extrabold" style={{"fontSize": "clamp(2.8rem, 8vw, 5.5rem)", "lineHeight": "1.05", "letterSpacing": "-0.03em"}}>{"In your browser."}</div>
                </div>

                <p className="text-lg text-muted-foreground text-center leading-relaxed mb-11 max-w-[500px]">
                    {"Write, preview, and version your Jac projects — no install needed. Open source, by devs for devs."}
                </p>

                <div className="flex items-center gap-3 mb-3.5">
                    <Button
                        size="lg"
                        disabled={isStarting}
                        onClick={lambda { handleGuestPlay(); }}
                        className="rounded-full font-semibold h-[52px] text-base px-7 bg-primary hover:bg-primary/80 hover:shadow-[0_0_24px_rgba(249,115,22,0.45)]"
                    >
                        {isStarting and <Spinner className="size-4" /> or None}
                        {"Just let me play"}
                        {not isStarting and <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4.5 ml-1" /> or None}
                    </Button>
                    <Button
                        size="lg"
                        variant="outline"
                        onClick={lambda { navigate("/auth"); }}
                        className="rounded-full h-[52px] text-base border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground"
                    >
                        {"Sign in to save"}
                    </Button>
                </div>

                <span className="text-xs text-muted-foreground">
                    {"No sign-up required " + String.fromCharCode(183) + " Projects tied to this browser"}
                </span>

                {startError and <span className="text-sm text-destructive mt-2">{startError}</span>}

            </div>
        </div>

        <div className="px-6 py-4 flex justify-center relative z-[1] border-t border-border/50">
            <div className="flex items-center gap-3 text-xs text-muted-foreground">
                <span className="cursor-pointer hover:text-foreground" onClick={lambda { navigate("/terms"); }}>{"Terms"}</span>
                <span className="text-border">{"/"}</span>
                <span className="cursor-pointer hover:text-foreground" onClick={lambda { navigate("/privacy"); }}>{"Privacy"}</span>
                <span className="text-border">{"/"}</span>
                <span>{"by devs, for devs " + String.fromCharCode(183) + " "}<a href="https://github.com/jaseci-labs/jaseci" className="text-muted-foreground/60 no-underline hover:text-muted-foreground">{"Jaseci Labs"}</a></span>
            </div>
        </div>

    </div>;
}
