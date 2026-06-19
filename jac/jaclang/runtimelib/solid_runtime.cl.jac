"""Solid client runtime shim for Jac JSX and framework bindings.

Framework-agnostic behavior (auth, walker/function fetch + auto-cache,
localStorage, navigation, error reporting, zod-schema proxy) lives in
`client_runtime_core.cl.jac`; this module imports and **re-exports** every core
symbol so `@jac/runtime` keeps exposing the full surface from a single module —
exactly as the React shim (`client_runtime.cl.jac`) does. On top of that it adds
the Solid-specific JSX factory: `__jacJsx` builds elements through Solid's
hyperscript runtime (`solid-js/h`) instead of `React.createElement`.

This file pulls in **no** React ecosystem package, which is the whole point of
the runtime split — a Solid build never resolves `react`, `react-router-dom`,
`react-hook-form`, or `@hookform/*`. It targets only Solid-native libraries:
routing via `@solidjs/router`, forms via `@tanstack/solid-form` (Standard Schema
natively, no resolver needed), and error/async parity via `solid-js`'s
`ErrorBoundary` / `Suspense`. Generated components emit JSX syntax compiled by
`vite-plugin-solid` (dom-expressions); there is no `__jacJsx` hyperscript factory
on this path. Solid's reactive primitives
(`createSignal`, `createEffect`, ...) are imported by the generated component code
straight from `solid-js` (see `SolidBackend.import_source`), not re-exported here.

Router parity uses thin adapters that bridge the API-shape gap between
react-router-dom and `@solidjs/router` (`Link`→`A`, `to`→`href`, `Route element=`
→`component=`). The generated file-based-routing entry uses `@solidjs/router`
natively (`<Router root={Layout}>`, `component={Page}`, and `props.children` for
nested/auth routes); `Routes` is a passthrough kept only for cross-framework
surface parity, and `Outlet` bridges a Jac layout's `<Outlet/>` to Solid Router's
`props.children` via `__JacOutletContext`. The same React-shaped names stay
exported from `@jac/runtime` for every framework.
"""

import from 'solid-js' {
    createSignal as solidCreateSignal,
    createMemo,
    createContext as solidCreateContext,
    useContext as solidUseContext,
    ErrorBoundary as SolidErrorBoundary,
    Suspense as SolidSuspense
}
import from '@solidjs/router' {
    Router as SolidRouter,
    Route as SolidRoute,
    A as SolidAnchor,
    Navigate as SolidNavigate,
    useNavigate as solidUseNavigate,
    useLocation as solidUseLocation,
    useParams as solidUseParams
}
import from '@tanstack/solid-form' { createForm }
import from 'zod' { z }

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

# --- Router bindings (@solidjs/router) --------------------------------------
# Directly compatible primitives are re-exported as-is; the rest are adapted in
# the impl. `JacSchema` is the zod proxy (framework-agnostic), built exactly as
# the React shim builds it. `useState`/`useEffect` are intentionally NOT exported
# (Solid components get `createSignal`/`createEffect` from `solid-js` directly).
glob:pub Router = SolidRouter,
     useNavigate = solidUseNavigate,
     useLocation = solidUseLocation,
     useParams = solidUseParams,
     JacSchema = __createJacSchema(z);

# Solid context carrying a parent/layout route's `props` (with `.children`) down
# to a Jac layout's `<Outlet/>`. `@solidjs/router` has no `<Outlet>`; it hands the
# matched nested route to the parent route's `component` as `props.children`, so
# `__jacMakeLayoutRoot` provides those props here and `Outlet` reads them back.
glob __JacOutletContext = solidCreateContext(None);

# Adapters that bridge react-router-dom's shape onto @solidjs/router (see impl).
def:pub Routes(props: dict) -> JsxElement;
def:pub Route(props: dict) -> JsxElement;
def:pub Link(props: dict) -> JsxElement;
def:pub Navigate(props: dict) -> JsxElement;
def:pub Outlet(props: dict = {}) -> JsxElement;
def:pub useRouter -> dict;
def:pub AuthGuard(redirect: str = "/login", children: any = None) -> JsxElement;
# Wraps a Jac layout component as a `@solidjs/router` `root`, publishing the
# route's `props` on `__JacOutletContext` so the layout's `<Outlet/>` resolves.
def:pub __jacMakeLayoutRoot(layout_component: any) -> any;

# --- Error boundary + async boundary ----------------------------------------
# `JacClientErrorBoundary` presents react-error-boundary's API
# ({FallbackComponent, onError, children}) over `solid-js`'s `ErrorBoundary`, so
# the same call sites work across frameworks. `JacAwaiting` wraps `Suspense`.
def:pub JacClientErrorBoundary(props: dict) -> JsxElement;
def:pub ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement;
def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;
def:pub JacAwaiting(props: dict) -> JsxElement;
def:pub __jacReactErrorHandler(error: any, info: any) -> None;

# --- Forms (@tanstack/solid-form + zod) -------------------------------------
def:pub useJacForm(
    form_mode: str = "onTouched", schema: any, onSubmit: any = None
) -> any;

def:pub JacForm(props: dict) -> JsxElement;
