"""Implementations for the framework-agnostic client runtime core.


Moved verbatim from client_runtime.impl.jac. Uses only ambient JS globals
(window, globalThis, fetch, JSON, Date, Reflect, ...) — no framework imports.
"""

impl navigate(path: str) -> None {
    window.history.pushState({}, "", path);
    window.dispatchEvent(Reflect.construct(PopStateEvent, ["popstate"]));
}

impl __createJacSchema(zodLib: any) -> any {
    handler = {
        "apply": lambda target: any , thisArg: any , argumentsList: any -> any {
        # When called as JacSchema({...}), call z.object({...})
        return zodLib.object.apply(zodLib, argumentsList); },
        "get": lambda target: any , prop: any , receiver: any -> any {
        # When accessing properties like JacSchema.string(), forward to z
        return zodLib[prop]; }
    };
    # Create a dummy function as the proxy target
    dummyFunc = lambda schema: any -> any { return zodLib.object(schema); };
    return Reflect.construct(Proxy, [dummyFunc, handler]);
}

impl __getApiBaseUrl -> str {
    # globalThis.__JAC_API_BASE_URL__ is replaced by Vite's define at build time.
    # Falls back to empty string (same-origin) when not configured.
    return globalThis.__JAC_API_BASE_URL__ || "";
}

# ============================================================================
# AUTO-CACHE INFRASTRUCTURE
# ============================================================================

# Read compiler-provided endpoint effects from __jac_init__ JSON
impl __getEndpointEffects -> dict {
    if not globalThis.__jacEndpointEffects__ {
        initEl = None;
        # Bare `document` throws ReferenceError outside the browser (Node test
        # harness), and `except Exception` does not catch JS errors - probe via
        # globalThis instead.
        if globalThis.document {
            try {
                initEl = document.getElementById("__jac_init__");
            } except Exception as e {
                console.warn("[jac-client] Failed to find __jac_init__ element:", e);
            }
        }
        if initEl {
            try {
                data = JSON.parse(initEl.textContent);
                globalThis.__jacEndpointEffects__ = data["endpointEffects"] or {};
            } except Exception as e {
                console.warn(
                    "[jac-client] Failed to parse __jac_init__ data, using empty effects:",
                    e
                );
                globalThis.__jacEndpointEffects__ = {};
            }
        } else {
            globalThis.__jacEndpointEffects__ = {};
        }
    }
    return globalThis.__jacEndpointEffects__;
}

# Get or initialize cache state on globalThis
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

# Check if a cache entry is still fresh
impl __isFresh(`entry: dict) -> bool {
    if not `entry {
        return False;
    }
    age = Date.now() - `entry["timestamp"];
    return age < `entry["ttl"];
}

# Get a cache entry and promote it in LRU order
impl __cacheGet(key: str) -> dict {
    state = __getCacheState();
    entry = state["cache"][key];
    if not entry {
        return None;
    }
    # Move to end (most recently used)
    idx = state["order"].indexOf(key);
    if idx > -1 {
        state["order"].splice(idx, 1);
    }
    state["order"].push(key);
    return entry;
}

# Store an entry in the cache with LRU eviction
impl __cacheSet(key: str, data: any, ttl: int) -> None {
    state = __getCacheState();
    # Remove existing entry if present
    if state["cache"][key] {
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }
    # Evict oldest if at capacity
    while len(state["order"]) >= state["config"]["maxEntries"] {
        __evictOldest();
    }
    state["cache"][key] = {"data": data, "timestamp": Date.now(), "ttl": ttl};
    state["order"].push(key);
}

# Evict the oldest cache entry
impl __evictOldest -> None {
    state = __getCacheState();
    if len(state["order"]) > 0 {
        oldest = state["order"].shift();
        if oldest and state["cache"][oldest] {
            Reflect.deleteProperty(state["cache"], oldest);
        }
    }
}

# Check if two lists share any element
impl __overlaps(list1: list, list2: list) -> bool {
    for item in list1 {
        if list2.includes(item) {
            return True;
        }
    }
    return False;
}

# Invalidate all cache entries for a given endpoint key prefix
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

# ============================================================================
# RAW FETCH HELPERS (no caching, just HTTP)
# ============================================================================

# Direct walker fetch (POST /walker/<name>[/<nodeId>])
impl __doWalkerFetch(`walker: str, nodeId: str, fields: dict) -> any {
    token = __getLocalStorage("jac_token");
    base_url = __getApiBaseUrl();
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
            __removeLocalStorage("jac_token");
            window.location.reload();
            return {};
        }
        error_text = await response.text();
        walker_name = f"{`walker}/{nodeId}" if nodeId else `walker;
        raise Exception(f"Walker {walker_name} failed: {error_text}");
    }
    payload = await response.json();
    return payload["data"] if payload["data"] else {};
}

# Direct function fetch (POST /function/<name>)
impl __doFuncFetch(function_name: str, args: dict) -> any {
    token = __getLocalStorage("jac_token");
    base_url = __getApiBaseUrl();
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

# ============================================================================
# AUTO-CACHE DISPATCH - shared by __jacSpawn and __jacCallFunction
# ============================================================================
impl __cachedEndpointCall(endpoint_key: str, args_key: str, fetch_fn: any) -> any {
    effects = __getEndpointEffects();
    info = effects[endpoint_key];
    state = __getCacheState();
    # If endpoint is a known READER, check cache first
    if info and not info["is_writer"] {
        cached = __cacheGet(args_key);
        if cached and __isFresh(cached) {
            return cached["data"];
        }
        # Dedup concurrent identical requests
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
    # If endpoint is a known WRITER, fetch then auto-invalidate readers
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
    # Unknown endpoint (no metadata) - direct fetch, no caching
    return await fetch_fn();
}

# ============================================================================
# PUBLIC API - __jacSpawn and __jacCallFunction with auto-caching
# ============================================================================
impl __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
    # Auth walkers always skip cache
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
    base_url = __getApiBaseUrl();
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
    base_url = __getApiBaseUrl();
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
            jacSetToken(token);
            return True;
        }
    }
    return False;
}

impl jacLogout -> None {
    __jacClearCache();
    __removeLocalStorage("jac_token");
    broker = __jacDesktopBroker();
    if broker {
        # Desktop: also drop the broker's *persisted* (on-disk) session so a
        # later login can't poll up this user's token. Best-effort and
        # non-blocking -- logout must not hang on the loopback server, and the
        # next login's `oauth/start` clears it again regardless.
        try {
            fetch(f"{broker}/session", {"method": "DELETE"}).catch(
                lambda e: any { console.warn(
                    "[jac-client] broker session clear failed:", e
                ); }
            );
        } except e {
            console.warn("[jac-client] broker session clear failed:", e);
        }
    }
}

impl jacIsLoggedIn -> bool {
    token = __getLocalStorage("jac_token");
    return token != None and token != "";
}

impl __jacClearCache -> None {
    # Drop every cached walker/function response; an auth change makes them
    # belong to a different principal.
    state = __getCacheState();
    for key in Object.keys(state["cache"]) {
        Reflect.deleteProperty(state["cache"], key);
    }
    state["order"].splice(0, state["order"].length);
}

impl jacSetToken(token: str) -> None {
    __jacClearCache();
    __setLocalStorage("jac_token", token);
}

impl __jacDesktopBroker -> str {
    # Set by the desktop host's document-start bootstrap (see
    # native_desktop_target). Absent in a normal web build, so this is "".
    if window.__JAC_DESKTOP__ and window.__JAC_BROKER__ {
        return window.__JAC_BROKER__;
    }
    return "";
}

impl __jacSleep(ms: int) -> None {
    await Reflect.construct(
        Promise, [lambda resolve: any { setTimeout(resolve, ms); }]
    );
}

impl __jacPollBrokerSession(broker: str, timeout_ms: int, interval_ms: int) -> str {
    deadline = Date.now() + timeout_ms;
    while Date.now() < deadline {
        try {
            resp = await fetch(f"{broker}/session");
            if resp.ok {
                data = await resp.json();
                token = data["token"] or "";
                if token {
                    return token;
                }
            }
        } except e {
            # Catch-all (incl. a native fetch TypeError): the browser may still be
            # open or the server momentarily busy -- keep polling, don't abort.
            console.warn("[jac-client] session poll failed:", e);
        }
        await __jacSleep(interval_ms);
    }
    return "";
}

impl jacSsoLogin(platform: str, api_base: str = "", operation: str = "login") -> bool {
    base = api_base or __getApiBaseUrl();
    broker = __jacDesktopBroker();
    if broker {
        # Desktop: the broker opens the *system* browser (OAuth providers refuse
        # embedded webviews) and the server redirects the token back to the
        # broker's loopback callback; we poll the broker session store for it.
        start_url = (
            f"{broker}/oauth/start?platform={encodeURIComponent(platform)}" + f"&operation={encodeURIComponent(
                operation
            )}" + f"&api_base={encodeURIComponent(base)}"
        );
        started = await fetch(start_url);
        if not started.ok {
            console.warn("[jac-client] oauth/start failed:", started.status);
            return False;
        }
        token = await __jacPollBrokerSession(broker, 300000, 1000);
        if token {
            jacSetToken(token);
            return True;
        }
        return False;
    }
    # Web: hand off to the server's SSO endpoint; it redirects back to the SPA's
    # configured callback route with `?token=...` (handled by the callback page).
    window.location.href = f"{base}/sso/{encodeURIComponent(platform)}/{encodeURIComponent(
        operation
    )}";
    return True;
}

impl __getLocalStorage(key: str) -> str {
    storage = globalThis.localStorage;
    return storage.getItem(key) if storage else "";
}

impl __setLocalStorage(key: str, value: str) -> None {
    storage = globalThis.localStorage;
    if storage {
        storage.setItem(key, value);
    }
}

impl __removeLocalStorage(key: str) -> None {
    storage = globalThis.localStorage;
    if storage {
        storage.removeItem(key);
    }
}

impl __jacReportError(
    message: str,
    stack: str = "",
    url: str = "",
    source: str = "",
    componentStack: str = ""
) -> None {
    try {
        baseUrl = __getApiBaseUrl();
        fetch(
            f"{baseUrl}/cl/__error__",
            {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify(
                    {
                        "message": message,
                        "stack": stack,
                        "url": url or window.location.href,
                        "source": source,
                        "componentStack": componentStack,
                        "timestamp": Reflect.construct(Date, []).toISOString()
                    }
                )
            }
        );
    } except Exception {
    # Intentionally silent - error reporting must never throw, as that
    # could cause infinite loops or mask the original error.
    }
}

"""Install global error handlers to catch unhandled JS errors and rejections.
Called once during app initialization.
"""
impl __jacInstallErrorHandlers -> None {
    if window.__jacErrorHandlersInstalled {
        return;
    }
    window.__jacErrorHandlersInstalled = True;
    # Catch synchronous errors (e.g., TypeError, ReferenceError)
    window.addEventListener(
        "error",
        lambda event: any { __jacReportError(
            event.message or "Unknown error",
            event.error.stack if event.error else "",
            event.filename or "",
            "window.onerror"
        ); }
    );
    # Catch unhandled promise rejections (e.g., failed fetch, async errors)
    window.addEventListener(
        "unhandledrejection",
        lambda event: any {
            reason = event.reason;
            message = "";
            stack = "";
            if reason {
                message = reason.message or str(reason);
                stack = reason.stack or "";
            } else {
                message = "Unhandled promise rejection";
            }
            __jacReportError(message, stack, "", "unhandledrejection");
        }
    );
}
