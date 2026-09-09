import from core.jacyac.github.auth { github_callback_mode, complete_native_github }
import from core.jacyac.github.login { complete_web_login }
import from "@jac/runtime" { Link }

def:pub GithubCallback -> JsxElement {
    has message: str = "Completing GitHub sign-in…";
    async def complete -> None {
        win: any = window;
        params: any = Reflect.construct(win.URLSearchParams, [window.location.search]);
        code = params.get("code") or "";
        state = params.get("state") or "";
        window.history.replaceState(None, "", window.location.pathname);
        if params.get("error") or not code or not state {
            message = "GitHub sign-in was cancelled. You can try again.";
            return;
        }
        try {
            mode = await github_callback_mode(state);
            if mode == "native" {
                message = await complete_native_github(code=code, state=state);
            } else {
                message = await complete_web_login(code, state);
            }
        } except Exception {
            message = "Could not finish sign-in. Please try again.";
        }
    }
    can with entry {
        complete();
    }
    return
        <main className="mx-auto max-w-lg px-6 py-32 text-center">
            <h1 className="text-2xl font-bold">JacYac · GitHub</h1>
            <p role="status" className="my-6">{message}</p>
            <Link to="/jacyac" className="text-primary">Return to JacYac</Link>
        </main>;
}
