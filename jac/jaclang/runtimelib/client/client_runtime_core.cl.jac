"""Platform-agnostic Jac client runtime (D9 core).

Imported and bundled into ``compiled/client_runtime.js`` together with either
``client_runtime.cl.jac`` (web) or ``client_runtime_native.cl.jac`` (RN).
Do not import this module from user apps — use ``@jac/runtime``.
"""

import from 'react' { * as React }
import from 'react-hook-form' { useForm }
import from '@hookform/resolvers/zod' { zodResolver }

# Renderer dispatch (R3) — default renderer is platform-specific.
def:pub __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement;
def:pub __jacRegisterRenderer(renderer: any) -> None;

def:pub __createJacSchema(zodLib: any) -> any;
async def:pub __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
def:pub jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
async def:pub __jacCallFunction(function_name: str, args: dict = {}) -> any;
def:pub __normalizeIdentity(x: any) -> dict;
def:pub __normalizeCredential(x: any) -> dict;
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

def:pub useJacForm(form_mode: str = "onTouched", schema: any) -> any;

def:pub __getEndpointEffects -> dict;
def:pub __getCacheState -> dict;
def:pub __isFresh(`entry: dict) -> bool;
def:pub __cacheGet(key: str) -> dict;
def:pub __cacheSet(key: str, data: any, ttl: int) -> None;
def:pub __evictOldest -> None;
async def:pub __doWalkerFetch(`walker: str, nodeId: str, fields: dict) -> any;
async def:pub __doFuncFetch(function_name: str, args: dict) -> any;
async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any;

def:pub __invalidateEndpoint(endpoint_key: str) -> None;
def:pub __overlaps(list1: list, list2: list) -> bool;

def:pub __jacReportError(
    message: str,
    stack: str = "",
    url: str = "",
    source: str = "",
    componentStack: str = ""
) -> None;

def:pub __jacReactErrorHandler(error: any, info: any) -> None;
