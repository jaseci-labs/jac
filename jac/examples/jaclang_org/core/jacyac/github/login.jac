import from "@jac/runtime" { jacSetToken, __getLocalStorage, __setLocalStorage }

async def:pub github_login -> bool;

async def:pub complete_web_login(code: str, state: str) -> str;
