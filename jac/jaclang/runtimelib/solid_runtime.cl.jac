"""Solid client runtime shim for Jac JSX and framework bindings.

Framework-agnostic behavior (auth, walker/function fetch + auto-cache,
localStorage, navigation, error reporting, zod-schema proxy) lives in
`client_runtime_core.cl.jac`; this module imports and **re-exports** every core
symbol so `@jac/runtime` keeps exposing the full surface from a single module —
exactly as the React shim (`client_runtime.cl.jac`) does. On top of that it adds
the Solid-specific JSX factory: `__jacJsx` builds elements through Solid's
hyperscript runtime (`solid-js/h`) instead of `React.createElement`.

Imports are written against `solid-js/h` only; this file pulls in **no** React
ecosystem package, which is the whole point of the runtime split — a Solid build
never resolves `react`, `react-router-dom`, or `react-hook-form`. Solid's
reactive primitives (`createSignal`, `createEffect`, ...) are imported by the
generated component code straight from `solid-js` (see `SolidBackend.import_source`),
not re-exported here. Router and form bindings are React-ecosystem-specific and are
a documented Solid follow-up (contract §8); they are intentionally absent.
"""

import from 'solid-js/h' { default as h }

# --- Framework-agnostic core: import + re-export so `@jac/runtime` is one module.
import from jaclang.runtimelib.client_runtime_core {
    navigate as _navigate,
    __createJacSchema as ___createJacSchema,
    __jacSpawn as ___jacSpawn,
    jacSpawn as _jacSpawn,
    __jacCallFunction as ___jacCallFunction,
    __normalizeIdentity as ___normalizeIdentity,
    __normalizeCredential as ___normalizeCredential,
    jacSignup as _jacSignup,
    jacLogin as _jacLogin,
    jacLogout as _jacLogout,
    jacIsLoggedIn as _jacIsLoggedIn,
    jacSsoLogin as _jacSsoLogin,
    jacSetToken as _jacSetToken,
    __jacClearCache as ___jacClearCache,
    __jacDesktopBroker as ___jacDesktopBroker,
    __jacPollBrokerSession as ___jacPollBrokerSession,
    __jacSleep as ___jacSleep,
    __getApiBaseUrl as ___getApiBaseUrl,
    __getLocalStorage as ___getLocalStorage,
    __setLocalStorage as ___setLocalStorage,
    __removeLocalStorage as ___removeLocalStorage,
    __getEndpointEffects as ___getEndpointEffects,
    __getCacheState as ___getCacheState,
    __isFresh as ___isFresh,
    __cacheGet as ___cacheGet,
    __cacheSet as ___cacheSet,
    __evictOldest as ___evictOldest,
    __doWalkerFetch as ___doWalkerFetch,
    __doFuncFetch as ___doFuncFetch,
    __cachedEndpointCall as ___cachedEndpointCall,
    __invalidateEndpoint as ___invalidateEndpoint,
    __overlaps as ___overlaps,
    __jacReportError as ___jacReportError,
    __jacInstallErrorHandlers as ___jacInstallErrorHandlers
}

# Internal compiler/runtime helpers (`__`-prefixed): emitted into and consumed
# only by generated code, never referenced from user `.cl.jac`, so a `glob`
# re-export (whose type is inference-only) is fine here. The public surface
# below is re-exported as typed `def`s instead -- see the note there. This block
# mirrors the React shim exactly so `@jac/runtime` is identical across frameworks.
glob:pub __createJacSchema = ___createJacSchema,
     __jacSpawn = ___jacSpawn,
     __jacCallFunction = ___jacCallFunction,
     __normalizeIdentity = ___normalizeIdentity,
     __normalizeCredential = ___normalizeCredential,
     __jacClearCache = ___jacClearCache,
     __jacDesktopBroker = ___jacDesktopBroker,
     __jacPollBrokerSession = ___jacPollBrokerSession,
     __jacSleep = ___jacSleep,
     __getApiBaseUrl = ___getApiBaseUrl,
     __getLocalStorage = ___getLocalStorage,
     __setLocalStorage = ___setLocalStorage,
     __removeLocalStorage = ___removeLocalStorage,
     __getEndpointEffects = ___getEndpointEffects,
     __getCacheState = ___getCacheState,
     __isFresh = ___isFresh,
     __cacheGet = ___cacheGet,
     __cacheSet = ___cacheSet,
     __evictOldest = ___evictOldest,
     __doWalkerFetch = ___doWalkerFetch,
     __doFuncFetch = ___doFuncFetch,
     __cachedEndpointCall = ___cachedEndpointCall,
     __invalidateEndpoint = ___invalidateEndpoint,
     __overlaps = ___overlaps,
     __jacReportError = ___jacReportError,
     __jacInstallErrorHandlers = ___jacInstallErrorHandlers;

# --- Public API: typed forwarding re-exports --------------------------------
# These re-export the core's public surface as `def`s rather than `glob`
# aliases. A `glob X = _X` re-export only acquires its type via *inference*, so
# when this runtime is compiled with `type_check=False` (the bundler and cl-test
# pipelines do exactly that) and cached, the alias's type decays to `Unknown`
# for any downstream module that type-checks against it. A `def` declaration
# carries its signature at *parse* time, so importers of `@jac/runtime` keep the
# real types (e.g. `jacIsLoggedIn -> bool`). The framework-agnostic bodies stay
# in `client_runtime_core`; these forward to them (see the impl file).
def:pub navigate(path: str) -> None;
def:pub jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
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
async def:pub jacSsoLogin(
    platform: str, api_base: str = "", operation: str = "login"
) -> bool;

def:pub jacSetToken(token: str) -> None;

# --- Solid-specific surface -------------------------------------------------
# The JSX factory called by every compiled component. Targets Solid's
# hyperscript runtime (`solid-js/h`) — the same factory name (`__jacJsx`) the
# React/Preact shims expose, so `EsJsxProcessor` stays framework-neutral.
def:pub __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement;
