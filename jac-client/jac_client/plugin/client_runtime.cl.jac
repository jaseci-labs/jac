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
# CACHE API - Caching for walker calls
# ============================================================================

"""Invalidate cache entries for a specific walker.

Args:
    walker: Walker name to invalidate
    nodeId: Optional node ID to narrow invalidation scope
"""
def:pub jacInvalidate(walker: str, nodeId: str = "") -> None;

"""Clear all cached data."""
def:pub jacClearCache() -> None;

"""Get cache metrics for monitoring.

Returns:
    dict with hits, misses, hitRate, evictions, cacheSize
"""
def:pub jacGetCacheMetrics() -> dict;

"""Get detailed cache statistics.

Returns:
    dict with entries, keys, config
"""
def:pub jacCacheStats() -> dict;

"""Prefetch walker result into cache (fire and forget).

Args:
    walker: Walker name to prefetch
    nodeId: Optional node ID
    fields: Optional walker parameters
"""
def:pub jacPrefetch(walker: str, nodeId: str = "", fields: dict = {}) -> None;

"""Check if cache is enabled."""
def:pub jacIsCacheEnabled() -> bool;

"""Enable or disable cache at runtime."""
def:pub jacSetCacheEnabled(enabled: bool) -> None;
