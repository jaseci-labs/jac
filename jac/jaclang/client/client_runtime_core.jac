obj:pub BridgeError(Exception) {
    has app: str = "",
        name: str = "",
        detail: str = "",
        status: int = 0,
        message: str = "";

    def postinit;
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

async def:pub __authPolicy -> any;
def:pub __normalizeIdentity(x: any, policy: any = None) -> dict[str, any];
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
def:pub __jacTokenExpired(token: str) -> bool;
def:pub __jacDropRejectedToken(sent: str) -> bool;

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

def __jacIsExtensionError(stack: str, filename: str = "") -> bool;

def __jacIsExtensionUrl(url: str) -> bool;

def __jacClaimErrorReport(message: str, stack: str) -> bool;

glob __JAC_EXTENSION_URL_PREFIXES: list[str] = [
         "chrome-extension://",
         "moz-extension://",
         "safari-web-extension://",
         "safari-extension://"
     ],
     __JAC_ERROR_REPORTS_PER_MINUTE: int = 10,
     __JAC_ERROR_REPORTS_PER_PAGE: int = 200,
     __JAC_STACK_FRAME_RE: any = RegExp(
         "^\\s*at\\s+(?:.*?\\()?(.*?)\\)?\\s*$|^[^@]*@(.*:\\d+:\\d+)\\s*$"
     ),
     __JAC_ENGINE_FRAME_RE: any = RegExp(
         "^(?:<anonymous>|native|\\[native code\\]|index \\d+|unknown location)?$"
     );

def:pub __jacInstallErrorHandlers -> None;

def:pub ErrorFallback(error: any, resetErrorBoundary: any) -> JsxElement;

def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;

def:pub __jacReactErrorHandler(error: any, info: any) -> None;

def:pub __unwrapFormSchema(schema: any) -> any;
