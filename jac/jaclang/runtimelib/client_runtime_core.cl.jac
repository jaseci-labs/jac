"""Framework-agnostic client runtime core for Jac.

This module holds every `@jac/runtime` symbol that does NOT depend on a UI
framework: auth (login/signup/SSO/token), walker & function fetch with the
auto-cache layer, localStorage access, the API base URL, SPA navigation via the
History API, global error reporting, and the zod-schema proxy helper.

It imports NO framework package (no `react`, `react-router-dom`,
`react-hook-form`, etc.) and uses only ambient JS globals (`window`,
`globalThis`, `fetch`, `JSON`, `Date`, `Reflect`, ...). The per-framework
runtime shims (`client_runtime.cl.jac` for React/Preact, `solid_runtime.cl.jac`
for Solid) import and re-export these symbols, then add their own JSX factory,
router, form, and suspense bindings. Keeping this file framework-free is what
lets a Solid build avoid pulling in the React ecosystem.
"""

# SPA navigation via the History API (no router dependency).
def:pub navigate(path: str) -> None;

# zod-schema proxy helper. Agnostic: takes the zod library as a parameter so the
# framework shim owns the actual `zod` import.
def:pub __createJacSchema(zodLib: any) -> any;

# Walker / function invocation with auto-caching.
async def:pub __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
def:pub jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
async def:pub __jacCallFunction(function_name: str, args: dict = {}) -> any;

def:pub __normalizeIdentity(x: any) -> dict;
def:pub __normalizeCredential(x: any) -> dict;

# Auth.
async def:pub jacSignup(
    identities_or_username: (str | list),
    credential_or_password: (str | dict),
    profile: (dict | None) = None
) -> dict;

async def:pub jacLogin(
    identity_or_username: (str | dict), credential_or_password: (str | dict)
) -> bool;

def:pub jacLogout -> None;
def:pub jacIsLoggedIn -> bool;

# SSO login. On the web, navigates to the server's `/sso/<platform>/<operation>`
# endpoint (the server redirects back to the SPA callback with the token). In the
# Jac-native desktop shell, hands the flow to the *system* browser via the
# loopback broker (RFC 8252) and polls the broker session store until the token
# lands -- returns True on success, False on timeout/failure.
async def:pub jacSsoLogin(
    platform: str, api_base: str = "", operation: str = "login"
) -> bool;

# Persist an auth token under the canonical `jac_token` key, clearing any cached
# pre-auth responses (same invariant as jacLogin). Used by SSO callback pages.
def:pub jacSetToken(token: str) -> None;

# Drop every cached walker/function response (called on any auth change).
def:pub __jacClearCache -> None;

# The loopback broker URL prefix when running inside the Jac-native desktop
# shell (set by the host's document-start bootstrap), else "".
def:pub __jacDesktopBroker -> str;

# Poll `GET <broker>/session` until a non-empty token appears or the timeout
# elapses; returns the token, or "" on timeout.
async def:pub __jacPollBrokerSession(
    broker: str, timeout_ms: int, interval_ms: int
) -> str;

async def:pub __jacSleep(ms: int) -> None;
def:pub __getApiBaseUrl -> str;
def:pub __getLocalStorage(key: str) -> str;
def:pub __setLocalStorage(key: str, value: str) -> None;
def:pub __removeLocalStorage(key: str) -> None;

# ============================================================================
# AUTO-CACHE INTERNALS - Compiler-driven caching for walker/function calls
# ============================================================================
def:pub __getEndpointEffects -> dict;
def:pub __getCacheState -> dict;
def:pub __isFresh(`entry: dict) -> bool;
def:pub __cacheGet(key: str) -> dict;
def:pub __cacheSet(key: str, data: any, ttl: int) -> None;
def:pub __evictOldest -> None;
async def:pub __doWalkerFetch(`walker: str, nodeId: str, fields: dict) -> any;
async def:pub __doFuncFetch(function_name: str, args: dict) -> any;
async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any;

def:pub __invalidateEndpoint(endpoint_key: str) -> None;
def:pub __overlaps(list1: list, list2: list) -> bool;

# ============================================================================
# Client Error Reporting (framework-agnostic global handlers)
# ============================================================================
def:pub __jacReportError(
    message: str,
    stack: str = "",
    url: str = "",
    source: str = "",
    componentStack: str = ""
) -> None;

def:pub __jacInstallErrorHandlers -> None;
