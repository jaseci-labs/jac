import from "@jac/runtime" { jacSetToken, __getLocalStorage, __setLocalStorage }
import from "expo-web-browser" { openBrowserAsync, dismissBrowser }
import from "expo-crypto" {
    randomUUID,
    digestStringAsync,
    CryptoDigestAlgorithm,
    CryptoEncoding
}

async def:pub github_login -> bool;

async def:pub complete_web_login(code: str, state: str) -> str;
