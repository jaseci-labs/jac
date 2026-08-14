import from 'react' { * as React }
import from 'react-hook-form' { useForm }
import from '@hookform/resolvers/zod' { zodResolver }

def:pub __jacJsx(
    tag: any, props: dict[str, any] = {}, children: any = []
) -> JsxElement;

def:pub __jacRegisterRenderer(renderer: any) -> None;
def:pub JacAwaiting(props: dict[str, any]) -> JsxElement;

def:pub __createJacSchema(zodLib: any) -> any;
async def:pub __jacSpawn(
    left: str, right: str = "", fields: dict[str, any] = {}
) -> any;

def:pub jacSpawn(left: str, right: str = "", fields: dict[str, any] = {}) -> any;

async def:pub __jacCallFunction(function_name: str, args: dict[str, any] = {}) -> any;
def:pub __normalizeIdentity(x: any) -> dict[str, any];
def:pub __normalizeCredential(x: any) -> dict[str, any];
async def:pub jacSignup(
    identities_or_username: (str | list[any]),
    credential_or_password: (str | dict[str, any]),
    profile: (dict[str, any] | None) = None
) -> dict[str, any];

async def:pub jacLogin(
    identity_or_username: (str | dict[str, any]),
    credential_or_password: (str | dict[str, any])
) -> bool;

def:pub jacLogout -> None;
def:pub jacIsLoggedIn -> bool;

def:pub useJacForm(form_mode: str = "onTouched", schema: any) -> any;

def:pub __getEndpointEffects -> dict[str, any];
def:pub __getCacheState -> dict[str, any];
def:pub __isFresh(`entry: dict[str, any]) -> bool;
def:pub __cacheGet(key: str) -> dict[str, any];
def:pub __cacheSet(key: str, data: any, ttl: int) -> None;
def:pub __evictOldest -> None;
async def:pub __doWalkerFetch(
    `walker: str, nodeId: str, fields: dict[str, any]
) -> any;

async def:pub __doFuncFetch(function_name: str, args: dict[str, any]) -> any;
async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any;

def:pub __invalidateEndpoint(endpoint_key: str) -> None;
def:pub __overlaps(list1: list[any], list2: list[any]) -> bool;

def:pub __jacReportError(
    message: str,
    stack: str = "",
    url: str = "",
    source: str = "",
    componentStack: str = ""
) -> None;

def:pub __jacReactErrorHandler(error: any, info: any) -> None;
