"""Client-side runtime for Jac JSX and walker interactions."""

import from 'react' { * as React }
import from 'react' { useState as reactUseState, useEffect as reactUseEffect }
import from 'react-dom/client' { * as ReactDOM }
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

def:pub __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement;

# React hooks re-exported for auto-injection by `has` variables and `can with entry/exit` effects
glob:
    pub useState = reactUseState,
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
     JacClientErrorBoundary = ErrorBoundary;

def:pub useRouter -> dict;
def:pub navigate(path: str) -> None;
async def:pub __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
def:pub jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
async def:pub __jacCallFunction(function_name: str, args: dict = {}) -> any;
async def:pub jacSignup(username: str, password: str) -> dict;
async def:pub jacLogin(username: str, password: str) -> bool;
def:pub jacLogout -> None;
def:pub jacIsLoggedIn -> bool;
def:pub __getApiBaseUrl -> str;
def:pub __getLocalStorage(key: str) -> str;
def:pub __setLocalStorage(key: str, value: str) -> None;
def:pub __removeLocalStorage(key: str) -> None;
def:pub AuthGuard(redirect: str = "/login") -> JsxElement;
def:pub ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement;
def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;

# ============================================================================
# AUTO-CACHE INTERNALS - Compiler-driven caching for walker/function calls
# ============================================================================
def:pub __getEndpointEffects -> dict;
def:pub __getCacheState -> dict;
def:pub __isFresh(entry: dict) -> bool;
def:pub __cacheGet(key: str) -> dict;
def:pub __cacheSet(key: str, data: any, ttl: int) -> None;
def:pub __evictOldest -> None;
async def:pub __doWalkerFetch(walker: str, nodeId: str, fields: dict) -> any;
async def:pub __doFuncFetch(function_name: str, args: dict) -> any;
async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any;

def:pub __invalidateEndpoint(endpoint_key: str) -> None;
def:pub __overlaps(list1: list, list2: list) -> bool;
