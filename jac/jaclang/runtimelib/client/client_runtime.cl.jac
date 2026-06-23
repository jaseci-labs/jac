"""Web client runtime for Jac (D9 — imports core, adds DOM/router adapters)."""

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
import from 'zod' { z }
import from client_runtime_core {
    __createJacSchema,
    jacIsLoggedIn,
    useJacForm,
    __jacReportError
}

def:pub __jacGetRenderer -> any;
def:pub __jacWebCreate(tag: any, props: dict = {}, children: any = []) -> JsxElement;

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
def:pub navigate(path: str) -> None;
def:pub __getApiBaseUrl -> str;
def:pub __getLocalStorage(key: str) -> str;
def:pub __setLocalStorage(key: str, value: str) -> None;
def:pub __removeLocalStorage(key: str) -> None;
def:pub AuthGuard(redirect: str = "/login") -> JsxElement;
def:pub ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement;
def:pub JacAwaiting(props: dict) -> JsxElement;
def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;
def:pub JacForm(props: dict) -> JsxElement;
def:pub __jacInstallErrorHandlers -> None;
def:pub __jacWirePlatformAdapters -> None;
