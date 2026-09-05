impl navigate(path: str) -> None {
    window.history.pushState({}, "", path);
    window.dispatchEvent(Reflect.construct(PopStateEvent, ["popstate"]));
}

impl __createJacSchema(zodLib: any) -> any {
    handler = {
        "apply": lambda (target: any, thisArg: any, argumentsList: any) -> any { return zodLib.object.apply(
            zodLib, argumentsList
        ); },
        "get": lambda (target: any, prop: any, receiver: any) -> any { return zodLib[
            prop
        ]; }
    };

    dummyFunc = lambda (schema: any) -> any { return zodLib.object(schema); };
    return Reflect.construct(Proxy, [dummyFunc, handler]);
}

impl __getApiBaseUrl -> str {
    base: any = globalThis.__JAC_API_BASE_URL__;
    return base or "";
}

impl __getEndpointEffects -> dict {
    effects: any = globalThis.__jacEndpointEffects__;
    if effects {
        return effects;
    }
    initText: (str | None) = None;

    if globalThis.document {
        try {
            initEl = document.getElementById("__jac_init__");
            if isinstance(initEl, HTMLElement) {
                initText = initEl.textContent;
            }
        } except Exception as e {
            console.warn("[jac-client] Failed to find __jac_init__ element:", e);
        }
    }
    if initText {
        try {
            data: any = JSON.parse(initText);
            effects = data["endpointEffects"] or {};
        } except Exception as e {
            console.warn(
                "[jac-client] Failed to parse __jac_init__ data, using empty effects:",
                e
            );
            effects = {};
        }
    } else {
        effects = {};
    }
    globalThis.__jacEndpointEffects__ = effects;
    return effects;
}

impl __getCacheState -> dict {
    state: any = globalThis.__jacCacheState__;
    if not state {
        state = {
            "cache": {},
            "order": [],
            "pending": {},
            "config": {"maxEntries": 500, "defaultTtlMs": 60000}
        };
        globalThis.__jacCacheState__ = state;
    }
    return state;
}

impl __isFresh(`entry: dict) -> bool {
    if not `entry {
        return False;
    }
    age = Date.now() - `entry["timestamp"];
    return age < `entry["ttl"];
}

impl __cacheGet(key: str) -> dict | None {
    state = __getCacheState();
    `entry = state["cache"][key];
    if not `entry {
        return None;
    }

    idx = state["order"].indexOf(key);
    if idx > -1 {
        state["order"].splice(idx, 1);
    }
    state["order"].push(key);
    return `entry;
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

impl __overlaps(list1: list[str], list2: list[str]) -> bool {
    for item in list1 {
        if item in list2 {
            return True;
        }
    }
    return False;
}

impl __invalidateEndpoint(endpoint_key: str) -> None {
    state = __getCacheState();
    keys_to_delete = [];
    for key in Object.keys(state["cache"]) {
        if key.startswith(endpoint_key) {
            keys_to_delete.append(key);
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


impl __bridgeErrorFor(
    status: int, message: str, app: str = "", name: str = ""
) -> BridgeError {
    if status == 401 or status == 403 or status == 404 {
        return BridgeRejected(app=app, name=name, detail=message, status=status);
    }
    return BridgeError(app=app, name=name, detail=message, status=status);
}

impl __fetchOrRaise(url: str, init: dict, app: str, name: str) -> Response {
    try {
        return await fetch(url, init);
    } except Exception as fetch_err {
        raise __bridgeErrorFromFetch(fetch_err, app, name);
    }
}

impl __bridgeErrorFromFetch(err: any, app: str = "", name: str = "") -> BridgeError {
    if isinstance(err, BridgeError) {
        return err;
    }
    message = __errorMessage(err);
    if err and (err.name == "AbortError" or err.name == "TimeoutError") {
        return BridgeTimeout(app=app, name=name, detail=message);
    }
    return BridgeUnavailable(app=app, name=name, detail=message);
}

impl __bridgeApiBase(opts: (dict | None) = None) -> str {
    base_url = __getApiBaseUrl();
    route = opts["route"] if opts and opts["route"] else "";
    if route {
        return f"{base_url}{route}";
    }
    return base_url;
}

impl __doWalkerFetch(
    `walker: str, nodeId: str, fields: dict, opts: (dict | None) = None
) -> any {
    app = opts["app"] if opts and opts["app"] else "";
    token = __getLocalStorage("jac_token");
    base_url = __bridgeApiBase(opts);
    url = f"{base_url}/walker/{`walker}";
    if nodeId != "" {
        url = f"{base_url}/walker/{`walker}/{nodeId}";
    }
    headers = {"Content-Type": "application/json", "Accept": "application/json"};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    response = await __fetchOrRaise(
        url,
        {"method": "POST", "headers": headers, "body": JSON.stringify(fields)},
        app,
        `walker
    );
    if not response.ok {
        if response.status == 401 and not app {
            __removeLocalStorage("jac_token");
            window.location.reload();
            return {};
        }
        error_text = await response.text();
        walker_name = f"{`walker}/{nodeId}" if nodeId else `walker;
        raise __bridgeErrorFor(
            int(response.status),
            f"Walker {walker_name} failed: {error_text}",
            app,
            `walker
        );
    }
    payload = await response.json();
    return payload["data"] if payload["data"] else {};
}

impl __doFuncFetch(function_name: str, args: dict, opts: (dict | None) = None) -> any {
    app = opts["app"] if opts and opts["app"] else "";
    token = __getLocalStorage("jac_token");
    base_url = __bridgeApiBase(opts);
    headers = {"Content-Type": "application/json"};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    response = await __fetchOrRaise(
        f"{base_url}/function/{function_name}",
        {"method": "POST", "headers": headers, "body": JSON.stringify(args)},
        app,
        function_name
    );
    if not response.ok {
        if response.status == 401 and not app {
            __removeLocalStorage("jac_token");
            window.location.reload();
            return {};
        }
        error_text = await response.text();
        raise __bridgeErrorFor(
            int(response.status),
            f"Function {function_name} failed: {error_text}",
            app,
            function_name
        );
    }
    payload = await response.json();
    if not payload["ok"] {
        error_msg = __errorMessage(payload["error"]) or "Unknown error";
        raise BridgeError(
            app=app,
            name=function_name,
            detail=f"Function {function_name} failed: {error_msg}",
            status=int(response.status)
        );
    }
    result = None;
    try {
        if payload["data"] and "result" in payload["data"] {
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

impl __jacSpawn(
    left: str, right: str = "", fields: dict = {}, opts: (dict | None) = None
) -> any {
    if left == "login"
        or left == "signup"
        or left == "logout"
        or left == "refresh_token" {
        return await __doWalkerFetch(left, right, fields, opts);
    }
    app = opts["app"] if opts and opts["app"] else "";
    endpoint_key = f"walker:{left}";
    args_key = f"{endpoint_key}:{app}:{right}:{JSON.stringify(fields)}";
    return await __cachedEndpointCall(
        endpoint_key,
        args_key,
        lambda -> any { return __doWalkerFetch(left, right, fields, opts); }
    );
}

impl jacSpawn(
    left: str, right: str = "", fields: dict = {}, opts: (dict | None) = None
) -> any {
    return __jacSpawn(left, right, fields, opts);
}

impl __jacCallFunction(
    function_name: str, args: dict = {}, opts: (dict | None) = None
) -> any {
    app = opts["app"] if opts and opts["app"] else "";
    endpoint_key = f"func:{function_name}";
    args_key = f"{endpoint_key}:{app}:{JSON.stringify(args)}";
    return await __cachedEndpointCall(
        endpoint_key,
        args_key,
        lambda -> any { return __doFuncFetch(function_name, args, opts); }
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

impl __errorMessage(err: any) -> str {
    if err == None {
        return "";
    }
    if Object.prototype.toString.call(err) == "[object Object]" {
        return err["message"] if err["message"] else "";
    }
    return String(err);
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
            message = __errorMessage(error_data["error"]);
            return {"success": False, "error": message or "Signup failed"};
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
        data: any = JSON.parse(await response.text());
        token: (str | None) = None;
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
        try {
            fetch(f"{broker}/session", {"method": "DELETE"}).catch(
                lambda (e: any) { console.warn(
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
    is_desktop: any = globalThis.__JAC_DESKTOP__;
    broker: any = globalThis.__JAC_BROKER__;
    if is_desktop and broker {
        return broker;
    }
    return "";
}

impl __jacSleep(ms: int) -> None {
    await Reflect.construct(
        Promise, [lambda (resolve: any) { setTimeout(resolve, ms); }]
    );
}

impl __jacPollBrokerSession(broker: str, timeout_ms: int, interval_ms: int) -> str {
    deadline = Date.now() + timeout_ms;
    while Date.now() < deadline {
        try {
            resp = await fetch(f"{broker}/session");
            if resp.ok {
                data: any = await resp.json();
                token: any = data["token"] or "";
                if token {
                    return token;
                }
            }
        } except e {
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
        start_url = (
            f"{broker}/oauth/start?platform={encodeURIComponent(platform)}"
            + f"&operation={encodeURIComponent(operation)}"
            + f"&api_base={encodeURIComponent(base)}"
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

    window.location.href = f"{base}/sso/{encodeURIComponent(platform)}/{encodeURIComponent(
        operation
    )}";
    return True;
}

impl __getLocalStorage(key: str) -> str {
    if not globalThis.localStorage {
        return "";
    }
    value = localStorage.getItem(key);
    return value if value is not None else "";
}

impl __setLocalStorage(key: str, value: str) -> None {
    if globalThis.localStorage {
        localStorage.setItem(key, value);
    }
}

impl __removeLocalStorage(key: str) -> None {
    if globalThis.localStorage {
        localStorage.removeItem(key);
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
    } except Exception {}
}

impl __jacInstallErrorHandlers -> None {
    installed: any = globalThis.__jacErrorHandlersInstalled;
    if installed {
        return;
    }
    setattr(globalThis, "__jacErrorHandlersInstalled", True);

    window.addEventListener(
        "error",
        lambda (event: any) { __jacReportError(
            event.message or "Unknown error",
            event.error.stack if event.error else "",
            event.filename or "",
            "window.onerror"
        ); }
    );

    window.addEventListener(
        "unhandledrejection",
        lambda (event: any) {
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

impl ErrorFallback(error: any, resetErrorBoundary: any) -> JsxElement {
    <div
        role="alert"
        style={{
            minHeight: "100vh",
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            backgroundColor: "#f9fafb",
            fontFamily: "system-ui, sans-serif",

        }}
    >
        <div
            role="alert"
            style={{
                minHeight: "100vh",
                display: "flex",
                flexDirection: "column",
                justifyContent: "center",
                alignItems: "center",
                backgroundColor: "#f9fafb",
                fontFamily: "system-ui, sans-serif",

            }}
        >
            <h2 style={{color: "#dc2626", marginBottom: "12px"}}>
                🚨 Something went wrong
            </h2>
            <p style={{color: "#374151", marginBottom: "16px"}}>
                An unexpected error occurred. Please try again.
            </p>
            <pre
                style={{
                    color: "#991b1b",
                    background: "#fee2e2",
                    padding: "12px",
                    borderRadius: "8px",
                    fontSize: "14px",
                    overflowX: "auto",
                    marginBottom: "16px",

                }}
            >
                {error.message}
            </pre>
            <button
                onClick={lambda { resetErrorBoundary(); }}
                style={{
                    backgroundColor: "#2563eb",
                    color: "#fff",
                    padding: "10px 16px",
                    borderRadius: "8px",
                    border: "none",
                    cursor: "pointer",
                    fontSize: "14px",

                }}
            >
                🔄 Try again
            </button>
        </div>
    </div>
}

impl errorOverlay(filePath: str, errors: str) -> JsxElement {
    return (
        <div
            style={{
                position: "fixed",
                top: 0,
                left: 0,
                width: "100%",
                height: "100%",
                background: "rgba(0, 0, 0, 0.85)",
                color: "#fff",
                fontFamily: "'Monaco', 'Menlo', 'Ubuntu Mono', monospace",
                fontSize: 14,
                zIndex: 999999,
                overflow: "auto",
                padding: 20,
                boxSizing: "border-box",

            }}
        >
            <div style={{maxWidth: 1200, margin: "0 auto"}}>
                <div
                    style={{
                        background: "#d32f2f",
                        color: "white",
                        padding: "16px 24px",
                        borderRadius: "8px 8px 0 0",
                        fontSize: 18,
                        fontWeight: "bold",

                    }}
                >
                    ⚠️ Compilation Error
                </div>
                <div
                    style={{
                        background: "#1e1e1e",
                        padding: 24,
                        borderRadius: "0 0 8px 8px",

                    }}
                >
                    <div style={{marginBottom: 16}}>
                        <div style={{color: "#888", marginBottom: 8}}>File:</div>
                        <div style={{color: "#64b5f6", fontWeight: "bold"}}>
                            {filePath}
                        </div>
                    </div>
                    <div>
                        <div style={{color: "#888", marginBottom: 8}}>Error:</div>
                        <pre
                            style={{
                                background: "#2d2d2d",
                                padding: 16,
                                borderRadius: 4,
                                overflowX: "auto",
                                margin: 0,
                                borderLeft: "4px solid #d32f2f",
                                lineHeight: 1.6,
                                color: "#ff6b6b",

                            }}
                        >
                            {errors}
                        </pre>
                    </div>
                    <div
                        style={{
                            marginTop: 24,
                            paddingTop: 16,
                            borderTop: "1px solid #444",
                            color: "#888",
                            fontSize: 13,

                        }}
                    >
                        💡 Fix the error and save the file to continue development.
                    </div>
                </div>
            </div>
        </div>
    );
}

impl __jacReactErrorHandler(error: any, info: any) -> None {
    try {
        message = error.message if error else "Unknown error";
        stack = error.stack if error else "";
        componentStack = info.componentStack if info else "";
        __jacReportError(message, stack, "", "ErrorBoundary", componentStack);
    } except Exception {}
}

impl __unwrapFormSchema(schema: any) -> any {
    actualSchema = schema;
    try {
        if not schema.shape {
            if schema._def and schema._def.schema {
                actualSchema = schema._def.schema;
            } elif schema.`def and schema.`def.schema {
                actualSchema = schema.`def.schema;
            }
        }
    } except Exception as e {
        console.warn("Failed to unwrap schema:", e);
    }
    return actualSchema;
}
