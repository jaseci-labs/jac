impl __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement {
    if tag == None {
        tag = React.Fragment;
    }
    childrenArray = [];
    if children != None {
        if Array.isArray(children) {
            childrenArray = children;
        } else {
            childrenArray = [children];
        }
    }
    reactChildren = [];
    for child in childrenArray {
        if child != None {
            reactChildren.append(child);
        }
    }
    if len(reactChildren) > 0 {
        args = [tag, props];
        for child in reactChildren {
            args.append(child);
        }
        return React.createElement.apply(React, args);
    } else {
        return React.createElement(tag, props);
    }
}

impl useRouter -> dict {
    navigate = reactRouterUseNavigate();
    location = reactRouterUseLocation();
    params = reactRouterUseParams();
    return {
        "navigate": navigate,
        "location": location,
        "params": params,
        "pathname": location.pathname,
        "search": location.search,
        "hash": location.hash
    };
}

impl navigate(path: str) -> None {
    window.history.pushState({}, "", path);
    window.dispatchEvent(Reflect.construct(PopStateEvent, ["popstate"]));
}

impl __getApiBaseUrl -> str {
    # globalThis.__JAC_API_BASE_URL__ is replaced by Vite's define at build time.
    # Falls back to empty string (same-origin) when not configured.
    return globalThis.__JAC_API_BASE_URL__ || "";
}

impl __jacCallFunction(function_name: str, args: dict = {}) -> any {
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
        raise Error(f"Function {function_name} failed: {error_text}") ;
    }
    payload = await response.json();
    if not payload["ok"] {
        error_msg = payload["error"] if payload["error"] else "Unknown error";
        raise Error(f"Function {function_name} failed: {error_msg}") ;
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

impl jacIsLoggedIn -> bool {
    token = __getLocalStorage("jac_token");
    return token != None and token != "";
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

# ============================================================================
# CACHE IMPLEMENTATION
# ============================================================================

# Get or initialize cache state on globalThis
impl __getCacheState() -> dict {
    if not globalThis.__jacCacheState__ {
        globalThis.__jacCacheState__ = {
            "cache": {},
            "order": [],
            "pending": {},
            "metrics": {"hits": 0, "misses": 0, "evictions": 0},
            "config": {"maxEntries": 500, "defaultTtlMs": 60000, "enabled": True}
        };
    }
    return globalThis.__jacCacheState__;
}

impl __getCacheKey(walker: str, nodeId: str, fields: dict) -> str {
    return f"{walker}:{nodeId}:{JSON.stringify(fields)}";
}

impl __isFresh(entry: dict) -> bool {
    if not entry {
        return False;
    }
    if entry["ttl"] <= 0 {
        return False;
    }
    age = Date.now() - entry["timestamp"];
    return age < entry["ttl"];
}

impl __evictOldest() -> None {
    state = __getCacheState();
    if len(state["order"]) > 0 {
        oldest = state["order"].shift();
        if oldest {
            if state["cache"][oldest] {
                Reflect.deleteProperty(state["cache"], oldest);
                state["metrics"]["evictions"] = state["metrics"]["evictions"] + 1;
            }
        }
    }
}

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

impl __cacheSet(key: str, data: any, ttl: int) -> None {
    state = __getCacheState();
    # Remove existing entry if present
    if state["cache"][key] {
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }
    # Evict if at capacity
    while len(state["order"]) >= state["config"]["maxEntries"] {
        __evictOldest();
    }
    state["cache"][key] = {"data": data, "timestamp": Date.now(), "ttl": ttl};
    state["order"].push(key);
}

impl __cacheDelete(key: str) -> None {
    state = __getCacheState();
    if state["cache"][key] {
        Reflect.deleteProperty(state["cache"], key);
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }
}

# Walkers that should never be cached
glob UNCACHEABLE_WALKERS: list = ["login", "signup", "logout", "refresh_token"];

impl __isUncacheable(walker: str) -> bool {
    return UNCACHEABLE_WALKERS.includes(walker);
}

impl __doFetch(walker: str, nodeId: str, fields: dict) -> any {
    token = __getLocalStorage("jac_token");
    base_url = __getApiBaseUrl();
    url = f"{base_url}/walker/{walker}";
    if nodeId != "" {
        url = f"{base_url}/walker/{walker}/{nodeId}";
    }
    headers = {"Content-Type": "application/json", "Accept": "application/json"};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    response = await fetch(
        url, {"method": "POST", "headers": headers, "body": JSON.stringify(fields)}
    );
    if not response.ok {
        error_text = await response.text();
        walker_name = f"{walker}/{nodeId}" if nodeId else walker;
        raise Error(f"Walker {walker_name} failed: {error_text}");
    }
    payload = await response.json();
    return payload["data"] if payload["data"] else {};
}

# __jacSpawn with caching support
impl __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
    # Initialize cache state if needed
    if not globalThis.__jacCacheState__ {
        globalThis.__jacCacheState__ = {
            "cache": {},
            "order": [],
            "pending": {},
            "metrics": {"hits": 0, "misses": 0, "evictions": 0},
            "config": {"maxEntries": 500, "defaultTtlMs": 60000, "enabled": True}
        };
    }
    state = globalThis.__jacCacheState__;

    # Skip cache if disabled or auth walker - do direct fetch
    skipCache = False;
    if not state["config"]["enabled"] {
        skipCache = True;
    }
    if left == "login" {
        skipCache = True;
    }
    if left == "signup" {
        skipCache = True;
    }
    if left == "logout" {
        skipCache = True;
    }
    if left == "refresh_token" {
        skipCache = True;
    }

    if skipCache {
        # Direct fetch without caching
        tkn = globalThis.localStorage.getItem("jac_token");
        base = globalThis.__JAC_API_BASE_URL__ || "";
        url = f"{base}/walker/{left}";
        if right != "" {
            url = f"{base}/walker/{left}/{right}";
        }
        hdrs = {"Content-Type": "application/json", "Accept": "application/json"};
        if tkn {
            hdrs["Authorization"] = f"Bearer {tkn}";
        }
        resp = await fetch(url, {"method": "POST", "headers": hdrs, "body": JSON.stringify(fields)});
        if not resp.ok {
            errTxt = await resp.text();
            wName = f"{left}/{right}" if right else left;
            raise Error(f"Walker {wName} failed: {errTxt}");
        }
        pl = await resp.json();
        return pl["data"] if pl["data"] else {};
    }

    cacheKey = f"{left}:{right}:{JSON.stringify(fields)}";

    # Check cache first
    cached = state["cache"][cacheKey];
    if cached {
        age = Date.now() - cached["timestamp"];
        if age < cached["ttl"] {
            # Move to end of order (LRU)
            idx = state["order"].indexOf(cacheKey);
            if idx > -1 {
                state["order"].splice(idx, 1);
            }
            state["order"].push(cacheKey);
            state["metrics"]["hits"] = state["metrics"]["hits"] + 1;
            return cached["data"];
        }
    }

    # Cache miss
    state["metrics"]["misses"] = state["metrics"]["misses"] + 1;

    # Check for pending request (deduplication)
    if state["pending"][cacheKey] {
        return await state["pending"][cacheKey];
    }

    # Make the request - inline fetch
    tkn2 = globalThis.localStorage.getItem("jac_token");
    base2 = globalThis.__JAC_API_BASE_URL__ || "";
    url2 = f"{base2}/walker/{left}";
    if right != "" {
        url2 = f"{base2}/walker/{left}/{right}";
    }
    hdrs2 = {"Content-Type": "application/json", "Accept": "application/json"};
    if tkn2 {
        hdrs2["Authorization"] = f"Bearer {tkn2}";
    }
    fetchPromise = fetch(url2, {"method": "POST", "headers": hdrs2, "body": JSON.stringify(fields)});
    state["pending"][cacheKey] = fetchPromise;

    try {
        resp2 = await fetchPromise;
        if not resp2.ok {
            errTxt2 = await resp2.text();
            wName2 = f"{left}/{right}" if right else left;
            raise Error(f"Walker {wName2} failed: {errTxt2}");
        }
        pl2 = await resp2.json();
        data = pl2["data"] if pl2["data"] else {};

        # Store in cache
        if state["cache"][cacheKey] {
            idx = state["order"].indexOf(cacheKey);
            if idx > -1 {
                state["order"].splice(idx, 1);
            }
        }
        # Evict oldest if at capacity
        while len(state["order"]) >= state["config"]["maxEntries"] {
            oldest = state["order"].shift();
            if oldest {
                Reflect.deleteProperty(state["cache"], oldest);
                state["metrics"]["evictions"] = state["metrics"]["evictions"] + 1;
            }
        }
        state["cache"][cacheKey] = {"data": data, "timestamp": Date.now(), "ttl": state["config"]["defaultTtlMs"]};
        state["order"].push(cacheKey);
        return data;
    } finally {
        Reflect.deleteProperty(state["pending"], cacheKey);
    }
}

impl jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
    return __jacSpawn(left, right, fields);
}

# Invalidate cache entries for a specific walker
impl jacInvalidate(walker: str, nodeId: str = "") -> None {
    # Handle undefined nodeId (JS default param issue)
    actualNodeId = nodeId or "";
    console.log("[jacInvalidate] Called with walker:", walker, "nodeId:", actualNodeId);
    if not globalThis.__jacCacheState__ {
        console.log("[jacInvalidate] No cache state exists");
        return;
    }
    state = globalThis.__jacCacheState__;
    prefix = f"{walker}:{actualNodeId}";
    console.log("[jacInvalidate] Looking for keys with prefix:", prefix);
    console.log("[jacInvalidate] Current cache keys:", Object.keys(state["cache"]));
    keysToDelete = [];
    for key in Object.keys(state["cache"]) {
        if key.startsWith(prefix) {
            keysToDelete.push(key);
        }
    }
    console.log("[jacInvalidate] Keys to delete:", keysToDelete);
    for key in keysToDelete {
        Reflect.deleteProperty(state["cache"], key);
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }
    console.log("[jacInvalidate] Done. Remaining keys:", Object.keys(state["cache"]));
}

# Clear all cached data
impl jacClearCache() -> None {
    console.log("[jacClearCache] Called");
    if not globalThis.__jacCacheState__ {
        console.log("[jacClearCache] No cache state exists");
        return;
    }
    state = globalThis.__jacCacheState__;
    console.log("[jacClearCache] Clearing", Object.keys(state["cache"]).length, "entries");
    for key in Object.keys(state["cache"]) {
        Reflect.deleteProperty(state["cache"], key);
    }
    state["order"].splice(0, state["order"].length);
    console.log("[jacClearCache] Done");
}

# Get cache metrics
impl jacGetCacheMetrics() -> dict {
    if not globalThis.__jacCacheState__ {
        return {"hits": 0, "misses": 0, "hitRate": 0, "evictions": 0, "cacheSize": 0};
    }
    state = globalThis.__jacCacheState__;
    total = state["metrics"]["hits"] + state["metrics"]["misses"];
    hitRate = 0;
    if total > 0 {
        hitRate = state["metrics"]["hits"] / total;
    }
    return {
        "hits": state["metrics"]["hits"],
        "misses": state["metrics"]["misses"],
        "hitRate": hitRate,
        "evictions": state["metrics"]["evictions"],
        "cacheSize": len(state["order"])
    };
}

# Get cache statistics
impl jacCacheStats() -> dict {
    if not globalThis.__jacCacheState__ {
        return {"entries": 0, "keys": [], "config": {}};
    }
    state = globalThis.__jacCacheState__;
    return {
        "entries": len(state["order"]),
        "keys": Object.keys(state["cache"]),
        "config": state["config"]
    };
}

# Prefetch a walker result into cache
impl jacPrefetch(walker: str, nodeId: str = "", fields: dict = {}) -> None {
    # Handle undefined nodeId (JS default param issue)
    actualNodeId = nodeId or "";
    if not globalThis.__jacCacheState__ {
        return;
    }
    state = globalThis.__jacCacheState__;
    cacheKey = f"{walker}:{actualNodeId}:{JSON.stringify(fields)}";
    cached = state["cache"][cacheKey];
    if cached {
        age = Date.now() - cached["timestamp"];
        if age < cached["ttl"] {
            return;
        }
    }
    # Fire and forget
    __jacSpawn(walker, actualNodeId, fields);
}

# Check if cache is enabled
impl jacIsCacheEnabled() -> bool {
    if not globalThis.__jacCacheState__ {
        return True;
    }
    return globalThis.__jacCacheState__["config"]["enabled"];
}

# Enable or disable cache
impl jacSetCacheEnabled(enabled: bool) -> None {
    if not globalThis.__jacCacheState__ {
        globalThis.__jacCacheState__ = {
            "cache": {},
            "order": [],
            "pending": {},
            "metrics": {"hits": 0, "misses": 0, "evictions": 0},
            "config": {"maxEntries": 500, "defaultTtlMs": 60000, "enabled": enabled}
        };
        return;
    }
    globalThis.__jacCacheState__["config"]["enabled"] = enabled;
    if not enabled {
        jacClearCache();
    }
}

# Auth functions with cache clearing
impl jacSignup(username: str, password: str) -> dict {
    base_url = __getApiBaseUrl();
    response = await fetch(
        f"{base_url}/user/register",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"username": username, "password": password})
        }
    );
    if response.ok {
        data = JSON.parse(await response.text());
        token = None;
        if data["data"] {
            if data["data"]["token"] {
                token = data["data"]["token"];
            }
        }
        if token {
            jacClearCache();
            __setLocalStorage("jac_token", token);
            return {"success": True, "token": token, "username": username};
        }
        return {"success": False, "error": "No token received"};
    } else {
        error_text = await response.text();
        try {
            error_data = JSON.parse(error_text);
            errMsg = "Signup failed";
            if error_data["error"] != None {
                errMsg = error_data["error"];
            }
            return {"success": False, "error": errMsg};
        } except Exception {
            return {"success": False, "error": error_text};
        }
    }
}

impl jacLogin(username: str, password: str) -> bool {
    base_url = __getApiBaseUrl();
    response = await fetch(
        f"{base_url}/user/login",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"username": username, "password": password})
        }
    );
    if response.ok {
        data = JSON.parse(await response.text());
        token = None;
        try {
            if data["data"] {
                if data["data"]["token"] {
                    token = data["data"]["token"];
                }
            }
        } except Exception as e {
            console.warn("Failed to extract login token:", e);
        }
        if token {
            jacClearCache();
            __setLocalStorage("jac_token", token);
            return True;
        }
    }
    return False;
}

impl jacLogout -> None {
    jacClearCache();
    __removeLocalStorage("jac_token");
}

"""Auth guard component for file-based routing. Renders child routes if
authenticated, otherwise redirects to the login path."""
impl AuthGuard(redirect: str = "/login") -> JsxElement {
    if jacIsLoggedIn() {
        return
            <ReactRouterOutlet/>;
    }
    return
        <ReactRouterNavigate to={redirect} replace={True}/>;
}

impl ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement {
    return
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
                    {error.error.message}
                </pre>
                <button
                    onClick={lambda -> None { error.resetErrorBoundary();}}
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
        </div>;
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
                        <div style={{color: "#888", marginBottom: 8}}>
                            File:
                        </div>
                        <div style={{color: "#64b5f6", fontWeight: "bold"}}>
                            {filePath}
                        </div>
                    </div>
                    <div>
                        <div style={{color: "#888", marginBottom: 8}}>
                            Error:
                        </div>
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
