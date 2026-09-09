import from jaclang.client.auth_contract { SignupResult }
import from 'react' { * as React }
import from 'react' {
    useState as reactUseState,
    useEffect as reactUseEffect,
    useRef as reactUseRef,
    useSyncExternalStore as reactUseSyncExternalStore
}
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
import from '@tanstack/react-form' { useForm }
import from 'zod' { z }

import from jaclang.client.client_runtime_core {
    BridgeError as _BridgeError,
    BridgeUnavailable as _BridgeUnavailable,
    BridgeTimeout as _BridgeTimeout,
    BridgeRejected as _BridgeRejected,
    __bridgeErrorFor as ___bridgeErrorFor,
    __bridgeErrorFromFetch as ___bridgeErrorFromFetch,
    __bridgeApiBase as ___bridgeApiBase,
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
    __jacInstallErrorHandlers as ___jacInstallErrorHandlers,
    ErrorFallback as ___ErrorFallback,
    errorOverlay as ___errorOverlay,
    __jacReactErrorHandler as ___jacReactErrorHandler,
    __unwrapFormSchema as ___unwrapFormSchema
}

glob:pub BridgeError = _BridgeError,
     BridgeUnavailable = _BridgeUnavailable,
     BridgeTimeout = _BridgeTimeout,
     BridgeRejected = _BridgeRejected,
     __bridgeErrorFor = ___bridgeErrorFor,
     __bridgeErrorFromFetch = ___bridgeErrorFromFetch,
     __bridgeApiBase = ___bridgeApiBase;

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

glob:pub ErrorFallback = ___ErrorFallback,
     errorOverlay = ___errorOverlay,
     __jacReactErrorHandler = ___jacReactErrorHandler,
     __unwrapFormSchema = ___unwrapFormSchema;

def:pub navigate(path: str) -> None;
def:pub jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
async def:pub jacSignup(
    identities_or_username: (str | list),
    credential_or_password: (str | dict),
    profile: (dict | None) = None
) -> SignupResult;

async def:pub jacLogin(
    identity_or_username: (str | dict), credential_or_password: (str | dict)
) -> bool;

def:pub jacLogout -> None;
def:pub jacIsLoggedIn -> bool;
async def:pub jacSsoLogin(
    platform: str, api_base: str = "", operation: str = "login"
) -> bool;

def:pub jacSetToken(token: str) -> None;

def:pub __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement;

def:pub useJacState(initial: any) -> any;

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
def:pub AuthGuard(redirect: str = "/login", children: any = None) -> JsxElement;

def:pub JacAwaiting(props: dict[str, any]) -> JsxElement;
def:pub useJacForm(
    form_mode: str = "onTouched", schema: any, onSubmit: any = None
) -> any;

def:pub JacForm(props: dict[str, any]) -> JsxElement;
