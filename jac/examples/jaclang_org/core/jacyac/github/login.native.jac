import from "@jac/runtime" { jacSetToken, __getLocalStorage, __setLocalStorage }
import from "expo-web-browser" { openBrowserAsync, dismissBrowser }
import from "expo-crypto" {
    randomUUID,
    digestStringAsync,
    CryptoDigestAlgorithm,
    CryptoEncoding
}
import from core.async_utils { sleep }
import from .auth { begin_github, poll_github }

async def:pub github_login -> bool {
    nonce = randomUUID() + randomUUID();
    hash = await digestStringAsync(
        CryptoDigestAlgorithm.SHA256, nonce, {"encoding": CryptoEncoding.BASE64}
    );
    challenge = hash.replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
    started = await begin_github(
        challenge=challenge, mode="native", session_token=__getLocalStorage("jac_token")
    );
    if not started.ok {
        raise Error(started.error);
    }
    cancelled = {"value": False};
    browser = openBrowserAsync(started.url);
    browser.then(
        lambda (result: any) { cancelled["value"] = result.type
            in ["cancel", "dismiss"]; }
    );
    try {
        for i in range(300) {
            await sleep(2000);
            result = await poll_github(poll=started.poll);
            if result.error {
                raise Error(result.error);
            }
            if result.ok {
                jacSetToken(result.token);
                __setLocalStorage("jacyac_username", result.username);
                return True;
            }
            if cancelled["value"] {
                return False;
            }
        }
        raise Error("GitHub sign-in timed out. Please try again.");
    } finally {
        try {
            dismissBrowser();
        } except Exception {}
    }
}

async def:pub complete_web_login(code: str, state: str) -> str {
    return "Complete sign-in in the browser.";
}
