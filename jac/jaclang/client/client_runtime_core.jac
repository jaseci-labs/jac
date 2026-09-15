import from jaclang.client.auth_contract { SignupResult }
import from jaclang.client.endpoint_cache {
    __endpointKey,
    __getEndpointEffects as cache___getEndpointEffects,
    __getCacheState as cache___getCacheState,
    __isFresh as cache___isFresh,
    __cacheGet as cache___cacheGet,
    __cacheSet as cache___cacheSet,
    __evictOldest as cache___evictOldest,
    __overlaps as cache___overlaps,
    __invalidateEndpoint as cache___invalidateEndpoint,
    __cachedEndpointCall as cache___cachedEndpointCall,
    __invalidateEffects as cache___invalidateEffects,
    __jacClearCache as cache___jacClearCache
}

obj:pub BridgeError(Exception) {
    has app: str = "",
        name: str = "",
        detail: str = "",
        status: int = 0,
        message: str = "";

    def postinit {
        self.message = self.detail;
    }
}

obj:pub BridgeUnavailable(BridgeError) {}

obj:pub BridgeTimeout(BridgeError) {}

obj:pub BridgeRejected(BridgeError) {}

def:pub __bridgeErrorFor(
    status: int, message: str, app: str = "", name: str = ""
) -> BridgeError;

async def __fetchOrRaise(
    url: str, init: dict[str, any], app: str, name: str
) -> Response;

def:pub __bridgeErrorFromFetch(err: any, app: str = "", name: str = "") -> BridgeError;
def:pub __bridgeApiBase(opts: (dict[str, any] | None) = None) -> str;

def:pub navigate(path: str) -> None;

def:pub __createJacSchema(zodLib: any) -> any;

async def:pub __jacSpawn(
    left: str,
    right: str = "",
    fields: dict[str, any] = {},
    opts: (dict[str, any] | None) = None
) -> any;

def:pub jacSpawn(
    left: str,
    right: str = "",
    fields: dict[str, any] = {},
    opts: (dict[str, any] | None) = None
) -> any;

async def:pub __jacCallFunction(
    function_name: str, args: dict[str, any] = {}, opts: (dict[str, any] | None) = None
) -> any;

def:pub __normalizeIdentity(x: any) -> dict[str, any];
def:pub __normalizeCredential(x: any) -> dict[str, any];
def:pub __errorMessage(err: any) -> str;

async def:pub jacSignup(
    identities_or_username: (str | list[str | dict[str, any]]),
    credential_or_password: (str | dict[str, any]),
    profile: (dict[str, any] | None) = None
) -> SignupResult;

async def:pub jacLogin(
    identity_or_username: (str | dict[str, any]),
    credential_or_password: (str | dict[str, any])
) -> bool;

def:pub jacLogout -> None;
def:pub jacIsLoggedIn -> bool;

async def:pub jacSsoLogin(
    platform: str, api_base: str = "", operation: str = "login"
) -> bool;

def:pub jacSetToken(token: str) -> None;

def:pub __jacClearCache -> None;

def:pub __jacDesktopBroker -> str;

async def:pub __jacPollBrokerSession(
    broker: str, timeout_ms: int, interval_ms: int
) -> str;

async def:pub __jacSleep(ms: int) -> None;
def:pub __getApiBaseUrl -> str;
def:pub __getLocalStorage(key: str) -> str;
def:pub __setLocalStorage(key: str, value: str) -> None;
def:pub __removeLocalStorage(key: str) -> None;

def:pub __getEndpointEffects -> dict[str, any];
def:pub __getCacheState -> dict[str, any];
def:pub __isFresh(`entry: dict[str, any]) -> bool;
def:pub __cacheGet(key: str) -> dict[str, any] | None;
def:pub __cacheSet(key: str, data: any, ttl: int) -> None;
def:pub __evictOldest -> None;
async def:pub __doWalkerFetch(
    `walker: str,
    nodeId: str,
    fields: dict[str, any],
    opts: (dict[str, any] | None) = None
) -> any;

async def:pub __doFuncFetch(
    function_name: str, args: dict[str, any], opts: (dict[str, any] | None) = None
) -> any;

async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any;

def:pub __invalidateEffects(writes: list[str]) -> None;
def:pub __invalidateEndpoint(endpoint_key: str) -> None;
def:pub __overlaps(list1: list[str], list2: list[str]) -> bool;

def:pub __jacReportError(
    message: str,
    stack: str = "",
    url: str = "",
    source: str = "",
    componentStack: str = ""
) -> None;

def:pub __jacInstallErrorHandlers -> None;

def:pub ErrorFallback(error: any, resetErrorBoundary: any) -> JsxElement;

def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;

def:pub __jacReactErrorHandler(error: any, info: any) -> None;

def:pub __unwrapFormSchema(schema: any) -> any;
