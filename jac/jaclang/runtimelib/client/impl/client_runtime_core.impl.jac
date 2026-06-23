# D9: platform-agnostic client runtime. Web/native impl files supply
# ``__jacSeedEndpointEffects``, ``__jacHandleWalkerUnauthorized``, and
# ``__jacDefaultErrorReportUrl`` plus storage / API-base-url adapters.
impl __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement {
    return globalThis.__jacGetRenderer__().create(tag, props, children);
}

impl __jacRegisterRenderer(renderer: any) -> None {
    globalThis.__jacRenderer__ = renderer;
}

impl __createJacSchema(zodLib: any) -> any {
    handler = {
        "apply": lambda target: any , thisArg: any , argumentsList: any -> any { return zodLib.object.apply(
            zodLib, argumentsList
        ); },
        "get": lambda target: any , prop: any , receiver: any -> any { return zodLib[
            prop
        ]; }
    };
    dummyFunc = lambda schema: any -> any { return zodLib.object(schema); };
    return Reflect.construct(Proxy, [dummyFunc, handler]);
}

impl __getEndpointEffects -> dict {
    if not globalThis.__jacEndpointEffects__ {
        seed_fn = globalThis.__jacSeedEndpointEffects__;
        if seed_fn {
            globalThis.__jacEndpointEffects__ = seed_fn();
        } else {
            globalThis.__jacEndpointEffects__ = {};
        }
    }
    return globalThis.__jacEndpointEffects__;
}

impl __getCacheState -> dict {
    if not globalThis.__jacCacheState__ {
        globalThis.__jacCacheState__ = {
            "cache": {},
            "order": [],
            "pending": {},
            "config": {"maxEntries": 500, "defaultTtlMs": 60000}
        };
    }
    return globalThis.__jacCacheState__;
}

impl __isFresh(`entry: dict) -> bool {
    if not `entry {
        return False;
    }
    age = Date.now() - `entry["timestamp"];
    return age < `entry["ttl"];
}

impl __cacheGet(key: str) -> dict {
    state = __getCacheState();
    entry = state["cache"][key];
    if not entry {
        return None;
    }
    idx = state["order"].indexOf(key);
    if idx > -1 {
        state["order"].splice(idx, 1);
    }
    state["order"].push(key);
    return entry;
}

impl __cacheSet(key: str, data: any, ttl: int) -> None {
    state = __getCacheState();
    if state["cache"][key] {
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }
    while len(state["order"]) >= state["config"]["maxEntries"] {
        __evictOldest();
    }
    state["cache"][key] = {"data": data, "timestamp": Date.now(), "ttl": ttl};
    state["order"].push(key);
}

impl __evictOldest -> None {
    state = __getCacheState();
    if len(state["order"]) > 0 {
        oldest = state["order"].shift();
        if oldest and state["cache"][oldest] {
            Reflect.deleteProperty(state["cache"], oldest);
        }
    }
}

impl __overlaps(list1: list, list2: list) -> bool {
    for item in list1 {
        if list2.includes(item) {
            return True;
        }
    }
    return False;
}

impl __invalidateEndpoint(endpoint_key: str) -> None {
    state = __getCacheState();
    keys_to_delete = [];
    for key in Object.keys(state["cache"]) {
        if key.startsWith(endpoint_key) {
            keys_to_delete.push(key);
        }
    }
    for key in keys_to_delete {
        Reflect.deleteProperty(state["cache"], key);
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }
}

impl __doWalkerFetch(`walker: str, nodeId: str, fields: dict) -> any {
    token = globalThis.__jacGetLocalStorage__("jac_token");
    base_url = globalThis.__jacGetApiBaseUrl__();
    url = f"{base_url}/walker/{`walker}";
    if nodeId != "" {
        url = f"{base_url}/walker/{`walker}/{nodeId}";
    }
    headers = {"Content-Type": "application/json", "Accept": "application/json"};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    response = await fetch(
        url, {"method": "POST", "headers": headers, "body": JSON.stringify(fields)}
    );
    if not response.ok {
        if response.status == 401 {
            globalThis.__jacRemoveLocalStorage__("jac_token");
            handler = globalThis.__jacHandleWalkerUnauthorized__;
            if handler {
                handler();
            }
            return {};
        }
        error_text = await response.text();
        walker_name = f"{`walker}/{nodeId}" if nodeId else `walker;
        raise Exception(f"Walker {walker_name} failed: {error_text}");
    }
    payload = await response.json();
    return payload["data"] if payload["data"] else {};
}

impl __doFuncFetch(function_name: str, args: dict) -> any {
    token = globalThis.__jacGetLocalStorage__("jac_token");
    base_url = globalThis.__jacGetApiBaseUrl__();
    headers = {"Content-Type": "application/json"};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    response = await fetch(
        f"{base_url}/function/{function_name}",
        {"method": "POST", "headers": headers, "body": JSON.stringify(args)}
    );
    if not response.ok {
        error_text = await response.text();
        raise Exception(f"Function {function_name} failed: {error_text}");
    }
    payload = await response.json();
    if not payload["ok"] {
        error_msg = payload["error"] if payload["error"] else "Unknown error";
        raise Exception(f"Function {function_name} failed: {error_msg}");
    }
    result = None;
    try {
        if payload["data"] and payload["data"]["result"] {
            result = payload["data"]["result"];
        }
    } except Exception as e {
        console.warn(f"Failed to extract result for {function_name}:", e);
    }
    return result;
}

impl __cachedEndpointCall(endpoint_key: str, args_key: str, fetch_fn: any) -> any {
    effects = __getEndpointEffects();
    info = effects[endpoint_key];
    state = __getCacheState();
    if info and not info["is_writer"] {
        cached = __cacheGet(args_key);
        if cached and __isFresh(cached) {
            return cached["data"];
        }
        if state["pending"][args_key] {
            return await state["pending"][args_key];
        }
        fetch_promise = fetch_fn();
        state["pending"][args_key] = fetch_promise;
        try {
            data = await fetch_promise;
            __cacheSet(args_key, data, state["config"]["defaultTtlMs"]);
            return data;
        } finally {
            Reflect.deleteProperty(state["pending"], args_key);
        }
    }
    if info and info["is_writer"] {
        data = await fetch_fn();
        writer_touches = info["touches"];
        for endpoint_name in Object.keys(effects) {
            reader_info = effects[endpoint_name];
            if reader_info and not reader_info["is_writer"] {
                if writer_touches.includes("*")
                or __overlaps(reader_info["touches"], writer_touches) {
                    __invalidateEndpoint(endpoint_name);
                }
            }
        }
        return data;
    }
    return await fetch_fn();
}

impl __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
    if left == "login"
    or left == "signup"
    or left == "logout"
    or left == "refresh_token" {
        return await __doWalkerFetch(left, right, fields);
    }
    endpoint_key = f"walker:{left}";
    args_key = f"{endpoint_key}:{right}:{JSON.stringify(fields)}";
    return await __cachedEndpointCall(
        endpoint_key,
        args_key,
        lambda -> any { return __doWalkerFetch(left, right, fields); }
    );
}

impl jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
    return __jacSpawn(left, right, fields);
}

impl __jacCallFunction(function_name: str, args: dict = {}) -> any {
    endpoint_key = f"func:{function_name}";
    args_key = f"{endpoint_key}:{JSON.stringify(args)}";
    return await __cachedEndpointCall(
        endpoint_key,
        args_key,
        lambda -> any { return __doFuncFetch(function_name, args); }
    );
}

impl __normalizeIdentity(x: any) -> dict {
    if x != None and Object.prototype.toString.call(x) == "[object Object]" {
        return x;
    }
    return {"type": "username", "value": x};
}

impl __normalizeCredential(x: any) -> dict {
    if x != None and Object.prototype.toString.call(x) == "[object Object]" {
        return x;
    }
    return {"type": "password", "password": x};
}

impl jacSignup(
    identities_or_username: (str | list),
    credential_or_password: (str | dict),
    profile: (dict | None) = None
) -> dict {
    base_url = globalThis.__jacGetApiBaseUrl__();
    credential = __normalizeCredential(credential_or_password);
    identities = (
        identities_or_username
            if Array.isArray(identities_or_username)
            else [__normalizeIdentity(identities_or_username)]
    );
    body = {"identities": identities, "credential": credential};
    if profile != None {
        body["profile"] = profile;
    }
    response = await fetch(
        f"{base_url}/user/register",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify(body)
        }
    );
    if response.ok {
        body_text = await response.text();
        user_id = None;
        try {
            data = JSON.parse(body_text);
            if data["data"] and data["data"]["user_id"] {
                user_id = data["data"]["user_id"];
            }
        } except Exception as e {
            return {
                "success": False,
                "error": f"Signup response was not valid JSON: {e}"
            };
        }
        return {"success": True, "user_id": user_id};
    } else {
        error_text = await response.text();
        try {
            error_data = JSON.parse(error_text);
            return {
                "success": False,
                "error": error_data["error"]
                    if error_data["error"] != None
                    else "Signup failed"
            };
        } except Exception {
            return {"success": False, "error": error_text};
        }
    }
}

impl jacLogin(
    identity_or_username: (str | dict), credential_or_password: (str | dict)
) -> bool {
    base_url = globalThis.__jacGetApiBaseUrl__();
    identity = __normalizeIdentity(identity_or_username);
    credential = __normalizeCredential(credential_or_password);
    response = await fetch(
        f"{base_url}/user/login",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"identity": identity, "credential": credential})
        }
    );
    if response.ok {
        data = JSON.parse(await response.text());
        token = None;
        try {
            if data["data"] and data["data"]["token"] {
                token = data["data"]["token"];
            }
        } except Exception as e {
            console.warn("Failed to extract login token:", e);
        }
        if token {
            state = __getCacheState();
            for key in Object.keys(state["cache"]) {
                Reflect.deleteProperty(state["cache"], key);
            }
            state["order"].splice(0, state["order"].length);
            globalThis.__jacSetLocalStorage__("jac_token", token);
            return True;
        }
    }
    return False;
}

impl jacLogout -> None {
    state = __getCacheState();
    for key in Object.keys(state["cache"]) {
        Reflect.deleteProperty(state["cache"], key);
    }
    state["order"].splice(0, state["order"].length);
    globalThis.__jacRemoveLocalStorage__("jac_token");
}

impl jacIsLoggedIn -> bool {
    token = globalThis.__jacGetLocalStorage__("jac_token");
    return token != None and token != "";
}

impl useJacForm(form_mode: str, schema: any) -> any {
    return useForm(mode=form_mode, resolver=zodResolver(schema));
}

impl __jacReportError(
    message: str,
    stack: str = "",
    url: str = "",
    source: str = "",
    componentStack: str = ""
) -> None {
    try {
        baseUrl = globalThis.__jacGetApiBaseUrl__();
        url_fn = globalThis.__jacDefaultErrorReportUrl__;
        report_url = url or (url_fn() if url_fn else "");
        fetch(
            f"{baseUrl}/cl/__error__",
            {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify(
                    {
                        "message": message,
                        "stack": stack,
                        "url": report_url,
                        "source": source,
                        "componentStack": componentStack,
                        "timestamp": Reflect.construct(Date, []).toISOString()
                    }
                )
            }
        );
    } except Exception { }
}

impl __jacReactErrorHandler(error: any, info: any) -> None {
    try {
        message = error.message if error else "Unknown error";
        stack = error.stack if error else "";
        componentStack = info.componentStack if info else "";
        __jacReportError(message, stack, "", "ErrorBoundary", componentStack);
    } except Exception { }
}
