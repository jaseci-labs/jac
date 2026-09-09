import from jaclang.client.auth_contract { SignupResult }
import from jaclang.client.endpoint_cache {
    __jacClearCache,
    __endpointKey,
    __getEndpointEffects as cache___getEndpointEffects,
    __getCacheState as cache___getCacheState,
    __isFresh as cache___isFresh,
    __cacheGet as cache___cacheGet,
    __cacheSet as cache___cacheSet,
    __evictOldest as cache___evictOldest,
    __overlaps as cache___overlaps,
    __invalidateEndpoint as cache___invalidateEndpoint,
    __cachedEndpointCall as cache___cachedEndpointCall
}

import from 'react' { * as React }
import from 'react-hook-form' { useForm }
import from '@hookform/resolvers/zod' { zodResolver }

def:pub __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement;
def:pub __jacRegisterRenderer(renderer: any) -> None;
def:pub JacAwaiting(props: dict) -> JsxElement;

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

def:pub __bridgeErrorFromFetch(err: any, app: str = "", name: str = "") -> BridgeError;
def:pub __bridgeApiBase(opts: (dict | None) = None) -> str;

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

def:pub useJacForm(form_mode: str = "onTouched", schema: any) -> any;

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

def:pub __jacReactErrorHandler(error: any, info: any) -> None;
