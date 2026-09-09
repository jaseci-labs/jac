impl __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement {
    renderer: any = globalThis.__jacGetRenderer__();
    return renderer.create(tag, props, children);
}

impl __jacRegisterRenderer(renderer: any) -> None {
    globalThis.__jacRenderer__ = renderer;
}

impl JacAwaiting(props: dict) -> JsxElement {
    return React.createElement(
        React.Suspense, {"fallback": props["fallback"]}, props["children"]
    );
}

async def _awaitPlatformReady {
    ready: any = globalThis.__jacPlatformReady__;
    if ready {
        await ready;
    }
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

impl __getEndpointEffects -> dict {
    return cache___getEndpointEffects();
}

impl __getCacheState -> dict {
    return cache___getCacheState();
}

impl __isFresh(`entry: dict) -> bool {
    return cache___isFresh(`entry);
}

impl __cacheGet(key: str) -> dict | None {
    return cache___cacheGet(key);
}

impl __cacheSet(key: str, data: any, ttl: int) -> None {
    cache___cacheSet(key, data, ttl);
}

impl __evictOldest -> None {
    cache___evictOldest();
}

impl __overlaps(list1: list[str], list2: list[str]) -> bool {
    return cache___overlaps(list1, list2);
}

impl __invalidateEndpoint(endpoint_key: str) -> None {
    cache___invalidateEndpoint(endpoint_key);
}

impl __bridgeErrorFor(
    status: int, message: str, app: str = "", name: str = ""
) -> BridgeError {
    if status == 401 or status == 403 or status == 404 {
        return BridgeRejected(app=app, name=name, detail=message, status=status);
    }
    return BridgeError(app=app, name=name, detail=message, status=status);
}

impl __bridgeErrorFromFetch(err: any, app: str = "", name: str = "") -> BridgeError {
    if isinstance(err, BridgeError) {
        return err;
    }
    message = str(err.message) if err and err.message else str(err);
    if err and (err.name == "AbortError" or err.name == "TimeoutError") {
        return BridgeTimeout(app=app, name=name, detail=message);
    }
    return BridgeUnavailable(app=app, name=name, detail=message);
}

impl __bridgeApiBase(opts: (dict | None) = None) -> str {
    base_url = globalThis.__jacGetApiBaseUrl__();
    route = opts["route"] if opts and opts["route"] else "";
    if route {
        return f"{base_url}{route}";
    }
    return str(base_url);
}

impl __doWalkerFetch(
    `walker: str, nodeId: str, fields: dict, opts: (dict | None) = None
) -> any {
    await _awaitPlatformReady();
    app = opts["app"] if opts and opts["app"] else "";
    token = globalThis.__jacGetLocalStorage__("jac_token");
    base_url = __bridgeApiBase(opts);
    url = f"{base_url}/walker/{`walker}";
    if nodeId != "" {
        url = f"{base_url}/walker/{`walker}/{nodeId}";
    }
    headers = {"Content-Type": "application/json", "Accept": "application/json"};
    if opts and opts["contract"] {
        headers["X-Jac-Endpoint"] = opts["contract"];
    }
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    try {
        response = await fetch(
            url,
            {
                "method": "POST",
                "headers": headers,
                "body": JSON.stringify(fields, globalThis.__jacFwReplacer__)
            }
        );
    } except Exception as fetch_err {
        raise __bridgeErrorFromFetch(fetch_err, app, `walker);
    }
    if not response.ok {
        if response.status == 401 and not app {
            globalThis.__jacRemoveLocalStorage__("jac_token");
            handler = globalThis.__jacHandleWalkerUnauthorized__;
            if handler {
                handler();
            }
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
    await _awaitPlatformReady();
    app = opts["app"] if opts and opts["app"] else "";
    token = globalThis.__jacGetLocalStorage__("jac_token");
    base_url = __bridgeApiBase(opts);
    headers = {"Content-Type": "application/json"};
    if opts and opts["contract"] {
        headers["X-Jac-Endpoint"] = opts["contract"];
    }
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    try {
        response = await fetch(
            f"{base_url}/function/{function_name}",
            {
                "method": "POST",
                "headers": headers,
                "body": JSON.stringify(args, globalThis.__jacFwReplacer__)
            }
        );
    } except Exception as fetch_err {
        raise __bridgeErrorFromFetch(fetch_err, app, function_name);
    }
    if not response.ok {
        if response.status == 401 and not app {
            globalThis.__jacRemoveLocalStorage__("jac_token");
            handler = globalThis.__jacHandleWalkerUnauthorized__;
            if handler {
                handler();
            }
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
        error_msg = payload["error"] if payload["error"] else "Unknown error";
        raise BridgeError(
            app=app,
            name=function_name,
            detail=f"Function {function_name} failed: {error_msg}",
            status=int(response.status)
        );
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
    return await cache___cachedEndpointCall(endpoint_key, args_key, fetch_fn);
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
    endpoint_key = __endpointKey("walker", left, opts);
    args_key = f"{endpoint_key}:{app}:{right}:{JSON.stringify(
        fields, globalThis.__jacFwReplacer__
    )}";
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
    endpoint_key = __endpointKey("func", function_name, opts);
    args_key = f"{endpoint_key}:{app}:{JSON.stringify(
        args, globalThis.__jacFwReplacer__
    )}";
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

impl jacSignup(
    identities_or_username: (str | list),
    credential_or_password: (str | dict),
    profile: (dict | None) = None
) -> SignupResult {
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
            "body": JSON.stringify(body, globalThis.__jacFwReplacer__)
        }
    );
    if response.ok {
        body_text = await response.text();
        user_id = "";
        try {
            data = JSON.parse(body_text);
            if data["data"] and data["data"]["user_id"] {
                candidate_id = data["data"]["user_id"];
                if not isinstance(candidate_id, str) {
                    return SignupResult(
                        success=False, error="Signup response has an invalid user ID"
                    );
                }
                user_id = candidate_id;
            }
        } except Exception as e {
            return SignupResult(
                success=False, error=f"Signup response was not valid JSON: {e}"
            );
        }
        if not user_id {
            return SignupResult(
                success=False, error="Signup response is missing its user ID"
            );
        }
        return SignupResult(success=True, user_id=user_id);
    } else {
        error_text = await response.text();
        try {
            error_data = JSON.parse(error_text);
            return SignupResult(
                success=False,
                status=int(response.status),
                error=str(error_data["error"] or "Signup failed")
            );
        } except Exception {
            return SignupResult(
                success=False, status=int(response.status), error=error_text
            );
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
            __jacClearCache();
            globalThis.__jacSetLocalStorage__("jac_token", token);
            return True;
        }
    }
    return False;
}

impl jacLogout -> None {
    __jacClearCache();
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
    } except Exception {}
}

impl __jacReactErrorHandler(error: any, info: any) -> None {
    try {
        message = error.message if error else "Unknown error";
        stack = error.stack if error else "";
        componentStack = info.componentStack if info else "";
        __jacReportError(message, stack, "", "ErrorBoundary", componentStack);
    } except Exception {}
}
