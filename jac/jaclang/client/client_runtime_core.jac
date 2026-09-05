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

async def __fetchOrRaise(url: str, init: dict, app: str, name: str) -> Response;
def:pub __bridgeErrorFromFetch(err: any, app: str = "", name: str = "") -> BridgeError;
def:pub __bridgeApiBase(opts: (dict | None) = None) -> str;

def:pub navigate(path: str) -> None;

def:pub __createJacSchema(zodLib: any) -> any;

async def:pub __jacSpawn(
    left: str, right: str = "", fields: dict = {}, opts: (dict | None) = None
) -> any;

def:pub jacSpawn(
    left: str, right: str = "", fields: dict = {}, opts: (dict | None) = None
) -> any;

async def:pub __jacCallFunction(
    function_name: str, args: dict = {}, opts: (dict | None) = None
) -> any;

def:pub __normalizeIdentity(x: any) -> dict;
def:pub __normalizeCredential(x: any) -> dict;
def:pub __errorMessage(err: any) -> str;

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

def:pub __getEndpointEffects -> dict;
def:pub __getCacheState -> dict;
def:pub __isFresh(`entry: dict) -> bool;
def:pub __cacheGet(key: str) -> dict | None;
def:pub __cacheSet(key: str, data: any, ttl: int) -> None;
def:pub __evictOldest -> None;
async def:pub __doWalkerFetch(
    `walker: str, nodeId: str, fields: dict, opts: (dict | None) = None
) -> any;

async def:pub __doFuncFetch(
    function_name: str, args: dict, opts: (dict | None) = None
) -> any;

async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any;

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
