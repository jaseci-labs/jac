"""OAuth callback page — handles SSO redirect with JWT token."""
import from "@jac/runtime" { useNavigate }
import from ..components.ui.spinner { Spinner }

"""Handles /auth/callback after Google/GitHub SSO redirect.
Reads ?token= from URL, stores in localStorage, redirects to dashboard."""
def:pub OAuthCallback() -> Any {
    navigate = useNavigate();
    has errorMsg: str = "";
    has processed: bool = False;

    if not processed {
        processed = True;
        searchParams = Reflect.construct(URLSearchParams, [window.location.search]);
        token = searchParams.get("token") or "";
        errorParam = searchParams.get("error") or "";

        if errorParam {
            errorMsg = "Authentication failed: " + decodeURIComponent(errorParam);
        } elif token {
            localStorage.setItem("jac_token", token);
            try {
                payload = JSON.parse(atob(token.split(".")[1]));
                displayName = payload.username or payload.email or payload.name or "";
                if displayName {
                    localStorage.setItem("jac_display_name", displayName);
                }
            } except Exception {
            }
            window.location.href = "/dashboard";
        } else {
            errorMsg = "No authentication token received. Please try again.";
        }
    }

    if errorMsg {
        return <div className="min-h-screen bg-background flex flex-col items-center justify-center gap-4">
            <span className="text-destructive text-sm">{errorMsg}</span>
            <button
                className="text-primary underline text-sm cursor-pointer"
                onClick={lambda { navigate("/auth"); }}
            >
                {"Back to Sign In"}
            </button>
        </div>;
    }

    return <div className="min-h-screen bg-background flex flex-col items-center justify-center gap-3">
        <Spinner className="size-6 text-primary" />
        <span className="text-sm text-muted-foreground">{"Completing sign in..."}</span>
    </div>;
}
