import from react { useRef }
import from "@jac/runtime" { useNavigate }
import from ..services.ideService { githubOps }
import from ..components.ui.spinner { Spinner }

def:pub GitHubConnectCallback() -> Any {
    has status: str = "processing";
    has errorMsg: str = "";
    processedRef = useRef(False);
    navigate = useNavigate();

    if not processedRef.current {
        processedRef.current = True;
        searchParams = Reflect.construct(URLSearchParams, [window.location.search]);
        code = searchParams.get("code") or "";
        state = searchParams.get("state") or "";
        error = searchParams.get("error") or "";

        if error {
            errorMsg = decodeURIComponent(error);
            status = "error";
        } elif code {
            status = "exchanging";
            githubOps("exchange_code", {
                "code": code,
                "state": state
            }).then(lambda(result: Any) {
                if result and result.success {
                    status = "success";
                    setTimeout(lambda { window.location.href = "/dashboard"; }, 1500);
                } else {
                    errorMsg = (result.error if result else "Exchange failed");
                    status = "error";
                }
            });
        } else {
            errorMsg = "Missing authorization code";
            status = "error";
        }
    }

    if status == "success" {
        return <div className="min-h-screen bg-background flex flex-col items-center justify-center gap-3">
            <div className="text-4xl text-success">{"✓"}</div>
            <p className="text-foreground font-medium">{"GitHub connected successfully!"}</p>
            <p className="text-muted-foreground text-sm">{"Redirecting to dashboard..."}</p>
        </div>;
    }

    if status == "error" {
        return <div className="min-h-screen bg-background flex flex-col items-center justify-center gap-4">
            <div className="text-4xl text-destructive">{"✗"}</div>
            <p className="text-destructive font-medium">{"Failed to connect GitHub"}</p>
            <p className="text-muted-foreground text-sm">{errorMsg}</p>
            <button
                className="text-primary underline text-sm cursor-pointer"
                onClick={lambda { navigate("/dashboard"); }}
            >
                {"Back to Dashboard"}
            </button>
        </div>;
    }

    return <div className="min-h-screen bg-background flex flex-col items-center justify-center gap-3">
        <Spinner className="size-6 text-primary" />
        <span className="text-sm text-muted-foreground">
            {"Connecting your GitHub account..."}
        </span>
    </div>;
}
