import from "@jac/runtime" { jacSetToken, __getLocalStorage, __setLocalStorage }
import from .auth { begin_github, finish_github }

async def:pub github_login -> bool {
    browser: any = window;
    random_data: any = new(Uint8Array, 32);
    browser.crypto.getRandomValues(random_data);
    verifier: str = "";
    for byte in random_data {
        verifier += byte.toString(16).padStart(2, "0");
    }
    digest: any = await browser.crypto.subtle.digest(
        "SHA-256", new(TextEncoder).encode(verifier)
    );
    encoded: str = "";
    digest_bytes: any = new(Uint8Array, digest);
    for byte in digest_bytes {
        encoded += String.fromCharCode(byte);
    }
    challenge: str = browser.btoa(encoded).replaceAll("+", "-").replaceAll(
        "/", "_"
    ).replaceAll(
        "=", ""
    );
    result = await begin_github(
        challenge=challenge, session_token=__getLocalStorage("jac_token")
    );
    if not result.ok {
        raise Error(result.error);
    }
    sessionStorage.setItem("jacyac_github_" + result.state, verifier);
    window.location.assign(result.url);
    return False;
}

async def:pub complete_web_login(code: str, state: str) -> str {
    key = "jacyac_github_" + state;
    verifier = sessionStorage.getItem(key) or "";
    sessionStorage.removeItem(key);
    result = await finish_github(code=code, state=state, verifier=verifier);
    if not result.ok {
        return result.error;
    }
    jacSetToken(result.token);
    __setLocalStorage("jacyac_username", result.username);
    window.location.replace("/jacyac/scores");
    return "";
}
