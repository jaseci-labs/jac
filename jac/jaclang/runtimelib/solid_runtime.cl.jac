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

glob:pub Router = SolidRouter,
     useNavigate = solidUseNavigate,
     useLocation = solidUseLocation,
     useParams = solidUseParams,
     JacSchema = __createJacSchema(z);

glob __JacOutletContext = solidCreateContext(None);

def:pub Routes(props: dict) -> JsxElement;
def:pub Route(props: dict) -> JsxElement;
def:pub Link(props: dict) -> JsxElement;
def:pub Navigate(props: dict) -> JsxElement;
def:pub Outlet(props: dict = {}) -> JsxElement;
def:pub useRouter -> dict;
def:pub AuthGuard(redirect: str = "/login", children: any = None) -> JsxElement;

def:pub __jacMakeLayoutRoot(layout_component: any) -> any;

def:pub JacClientErrorBoundary(props: dict) -> JsxElement;
def:pub ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement;
def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;
def:pub JacAwaiting(props: dict) -> JsxElement;
def:pub __jacReactErrorHandler(error: any, info: any) -> None;

def:pub useJacForm(
    form_mode: str = "onTouched", schema: any, onSubmit: any = None
) -> any;

def:pub JacForm(props: dict) -> JsxElement;
