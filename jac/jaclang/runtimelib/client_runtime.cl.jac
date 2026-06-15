"""React (and Preact) client runtime shim for Jac JSX and framework bindings.

Framework-agnostic behavior (auth, walker/function fetch + auto-cache,
localStorage, navigation, error reporting, zod-schema proxy) lives in
`client_runtime_core.cl.jac`; this module imports and **re-exports** every core
symbol so `@jac/runtime` keeps exposing the full surface from a single module.
On top of that it adds the React-specific pieces: the `__jacJsx` element factory
(React.createElement), router bindings (react-router-dom), forms
(react-hook-form + zod), the `JacAwaiting` Suspense wrapper, and the error
boundary.

Imports are written against `react`; the Preact backend remaps them to
`preact/compat` at bundle time via `FrameworkBackend.vite_aliases`. DOM mounting
lives in the per-framework entry scripts, so this module imports no `react-dom`.
The Solid runtime (`solid_runtime.cl.jac`) re-exports the same core but supplies
its own `solid-js`-backed `__jacJsx`.
"""

import from 'react' { * as React }
import from 'react' { useState as reactUseState, useEffect as reactUseEffect }
import from 'react-router-dom' {
    BrowserRouter as ReactRouterBrowserRouter,
    Routes as ReactRouterRoutes,
    Route as ReactRouterRoute,
    Link as ReactRouterLink,
    Navigate as ReactRouterNavigate,
    Outlet as ReactRouterOutlet,
    useNavigate as reactRouterUseNavigate,
    useLocation as reactRouterUseLocation,
    useParams as reactRouterUseParams
}
import from 'react-error-boundary' { ErrorBoundary }
import from 'react-hook-form' { useForm }
import from '@hookform/resolvers/zod' { zodResolver }
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

glob:pub navigate = _navigate,
     __createJacSchema = ___createJacSchema,
     __jacSpawn = ___jacSpawn,
     jacSpawn = _jacSpawn,
     __jacCallFunction = ___jacCallFunction,
     __normalizeIdentity = ___normalizeIdentity,
     __normalizeCredential = ___normalizeCredential,
     jacSignup = _jacSignup,
     jacLogin = _jacLogin,
     jacLogout = _jacLogout,
     jacIsLoggedIn = _jacIsLoggedIn,
     jacSsoLogin = _jacSsoLogin,
     jacSetToken = _jacSetToken,
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

# --- React-specific surface -------------------------------------------------
def:pub __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement;

# React hooks re-exported for auto-injection by `has` variables and `can with entry/exit` effects
glob:pub useState = reactUseState,
     useEffect = reactUseEffect,
     Router = ReactRouterBrowserRouter,
     Routes = ReactRouterRoutes,
     Route = ReactRouterRoute,
     Link = ReactRouterLink,
     Navigate = ReactRouterNavigate,
     useNavigate = reactRouterUseNavigate,
     useLocation = reactRouterUseLocation,
     useParams = reactRouterUseParams,
     Outlet = ReactRouterOutlet,
     JacClientErrorBoundary = ErrorBoundary,
     JacSchema = __createJacSchema(z);

def:pub useRouter -> dict;
def:pub AuthGuard(redirect: str = "/login") -> JsxElement;
def:pub ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement;

# `<JacAwaiting fallback={...}>{children}</JacAwaiting>` - the compile-
# time wrapper for a `try { ... } awaiting { ... }` template clause. The
# view-lowering pass synthesizes this element on the `cl` target; the
# `fallback` prop is the awaiting-clause's rendered fragment, the
# children are the try-clause's rendered fragment. Today this is a thin
# wrapper over `React.Suspense`; once the language's `flow`/`wait` story
# integrates with `use()`, the same wrapper picks up real async behavior
# with no change at the call site. The `error` slot tied to `except`
# clauses is intentionally not part of v1 - wrap with a separate
# `JacClientErrorBoundary` for now.
def:pub JacAwaiting(props: dict) -> JsxElement;
def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;
def:pub useJacForm(form_mode: str = "onTouched", schema: any) -> any;
def:pub JacForm(props: dict) -> JsxElement;

# onError prop for JacClientErrorBoundary. Wired by entry-script generators
# so `info.componentStack` reaches the server (FallbackComponent's props
# don't include `info`, so reporting from there can't see componentStack).
def:pub __jacReactErrorHandler(error: any, info: any) -> None;
