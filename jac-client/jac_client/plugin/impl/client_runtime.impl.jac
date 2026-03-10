impl __jacJsx(tag: Any, props: dict = {}, children: Any = []) -> JsxElement {
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

impl __createJacSchema(zodLib: any) -> any {
    handler = {
        "apply": lambda target: any , thisArg: any , argumentsList: any  -> any {
        # When called as JacSchema({...}), call z.object({...})
        return zodLib.object.apply(zodLib, argumentsList); },
        "get": lambda target: any , prop: any , receiver: any  -> any {
        # When accessing properties like JacSchema.string(), forward to z
        return zodLib[prop]; }
    };
    # Create a dummy function as the proxy target
    dummyFunc = lambda schema: any  -> any { return zodLib.object(schema); };
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
        try {
            initEl = document.getElementById("__jac_init__");
        } except Exception {
            ;
        }
        if initEl {
            try {
                data = JSON.parse(initEl.textContent);
                globalThis.__jacEndpointEffects__ = data["endpointEffects"] or {};
            } except Exception {
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
impl __cacheSet(key: str, data: Any, ttl: int) -> None {
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
impl __doWalkerFetch(`walker: str, nodeId: str, fields: dict) -> Any {
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
impl __doFuncFetch(function_name: str, args: dict) -> Any {
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
# AUTO-CACHE DISPATCH — shared by __jacSpawn and __jacCallFunction
# ============================================================================
impl __cachedEndpointCall(endpoint_key: str, args_key: str, fetch_fn: Any) -> Any {
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
    # Unknown endpoint (no metadata) — direct fetch, no caching
    return await fetch_fn();
}

# ============================================================================
# PUBLIC API — __jacSpawn and __jacCallFunction with auto-caching
# ============================================================================
impl __jacSpawn(left: str, right: str = "", fields: dict = {}) -> Any {
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
        lambda -> Any { return __doWalkerFetch(left, right, fields); }
    );
}

impl jacSpawn(left: str, right: str = "", fields: dict = {}) -> Any {
    return __jacSpawn(left, right, fields);
}

impl __jacCallFunction(function_name: str, args: dict = {}) -> Any {
    endpoint_key = f"func:{function_name}";
    args_key = f"{endpoint_key}:{JSON.stringify(args)}";
    return await __cachedEndpointCall(
        endpoint_key,
        args_key,
        lambda -> Any { return __doFuncFetch(function_name, args); }
    );
}

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
        if data["data"] and data["data"]["token"] {
            token = data["data"]["token"];
        }
        if token {
            # Clear cache on auth change
            state = __getCacheState();
            for key in Object.keys(state["cache"]) {
                Reflect.deleteProperty(state["cache"], key);
            }
            state["order"].splice(0, state["order"].length);
            __setLocalStorage("jac_token", token);
            return {"success": True, "token": token, "username": username};
        }
        return {"success": False, "error": "No token received"};
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
            if data["data"] and data["data"]["token"] {
                token = data["data"]["token"];
            }
        } except Exception as e {
            console.warn("Failed to extract login token:", e);
        }
        if token {
            # Clear cache on auth change
            state = __getCacheState();
            for key in Object.keys(state["cache"]) {
                Reflect.deleteProperty(state["cache"], key);
            }
            state["order"].splice(0, state["order"].length);
            __setLocalStorage("jac_token", token);
            return True;
        }
    }
    return False;
}

impl jacLogout -> None {
    # Clear cache on auth change
    state = __getCacheState();
    for key in Object.keys(state["cache"]) {
        Reflect.deleteProperty(state["cache"], key);
    }
    state["order"].splice(0, state["order"].length);
    __removeLocalStorage("jac_token");
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

impl ErrorFallback(error: str, resetErrorBoundary: Any) -> JsxElement {
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

impl useJacForm(form_mode: str, schema: any) -> any {
    return useForm(mode=form_mode, resolver=zodResolver(schema));
}

"""Auto-generated JacForm component that can render forms based on Zod schemas with built-in validation and styling.
        Props:
        - schema: Zod schema defining the form fields and validation
        - onSubmit: function to call with form data on submit
        - layout: "vertical" (default), "horizontal", "inline", or "grid"
        - field_config: dict mapping field names to {type, label, placeholder, options, rows, showPasswordToggle, className, inputClassName, labelClassName}
            - type: REQUIRED - field type ("text", "email", "password", "number", "date", "datetime-local", "checkbox", "select", "radio", "textarea", etc.)
            - label: field label (defaults to field name)
            - placeholder: placeholder text
            - options: array of options for radio buttons (e.g., ["option1", "option2"])
            - rows: number of rows for textarea (default 4)
            - showPasswordToggle: boolean - show "Show password" checkbox for password fields (default false)
            - className, inputClassName, labelClassName: CSS classes for styling
        - submitLabel: custom label for the submit button (default "Submit")
        - submitClassName: custom className for submit button
        - gridColumns: number of columns for grid layout (default 2)
        - validateMode: validation mode for react-hook-form (default "onTouched")
        - className: additional CSS class for the form element
"""
impl JacForm(props: dict) -> JsxElement {
    # Destructure props (JSX passes all props as a single object)
    schema = props.schema;
    onSubmit = props.onSubmit;
    layout = props.layout || "vertical";
    field_config = props.field_config || {};
    submitLabel = props.submitLabel || "Submit";
    submitClassName = props.submitClassName || "";
    gridColumns = props.gridColumns || 2;
    validateMode = props.validateMode || "onTouched";
    className = props.className || "";
    # Extract field names from schema
    # Handle ZodEffects (schemas with .refine()) by unwrapping
    actualSchema = schema;
    try {
        if schema._def and schema._def.schema {
            # This is a ZodEffects, unwrap to get the base schema
            actualSchema = schema._def.schema;
        }
    } except Exception as e {
        console.warn("Failed to unwrap schema:", e);
    }
    schemaShape = actualSchema.shape || {};
    fieldNames = Object.keys(schemaShape);
    # Initialize form with the original schema (not the unwrapped one)
    form = useJacForm(validateMode, schema);
    errors = form.formState.errors;
    isSubmitting = form.formState.isSubmitting;
    isDirty = form.formState.isDirty;
    # # State for password visibility (separate state for each field)
    [passwordVisible, setPasswordVisible] = useState({});
    # Helper function to recursively unwrap Zod wrapper types
    def unwrapZodSchema(schema: any, depth: int = 0) -> any {
        maxDepth = 10;  # Prevent infinite recursion
        if not schema._def or depth >= maxDepth {
            return schema;
        }

        typeValue = schema._def.type;

        # Unwrap ZodOptional (.optional())
        if typeValue == "optional" and schema._def.innerType {
            return unwrapZodSchema(schema._def.innerType, depth + 1);
        }

        # Unwrap ZodDefault (.default())
        if typeValue == "default" and schema._def.innerType {
            return unwrapZodSchema(schema._def.innerType, depth + 1);
        }

        # Unwrap ZodEffects (.refine(), .transform(), etc.)
        if schema._def.checks and schema._def.schema {
            return unwrapZodSchema(schema._def.schema, depth + 1);
        }

        # Base case: not a wrapper type
        return schema;
    }
    # Helper: Render error message
    def renderError(error: any) -> JsxElement | None {
        if not error {
            return None;
        }
        return (
            <p style={{color: "#ef4444", fontSize: "0.85rem", marginTop: "0.25rem"}}>
                ⚠️{error.message}
            </p>
        );
    }
    # Helper: Extract enum options from schema
    def getEnumOptions(fieldSchema: any) -> list {
        unwrapped = unwrapZodSchema(fieldSchema);
        if unwrapped._def and unwrapped._def.entries {
            return Object.keys(unwrapped._def.entries);
        } elif unwrapped.def and unwrapped.def.entries {
            return Object.keys(unwrapped.def.entries);
        }
        return [];
    }
    # Helper: Render the actual input element based on type
    def renderInput(
        fieldType: str,
        field: any,
        error: any,
        config: dict,
        fieldSchema: any,
        fieldName: str
    ) -> JsxElement {
        inputClassName = config.inputClassName or "";
        labelClassName = config.labelClassName or "";
        placeholder = config.placeholder or "";
        label = config.label or fieldName;

        # Checkbox
        if fieldType == "checkbox" {
            watchValue = form.watch(fieldName);
            return (
                <label
                    style={{
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "0.5rem"
                    }}
                >
                    <input
                        type="checkbox"
                        name={field.name}
                        ref={field.ref}
                        onChange={field.onChange}
                        onBlur={field.onBlur}
                        checked={watchValue || False}
                        className={inputClassName}
                        style={{cursor: "pointer"}}
                    />
                    <span className={labelClassName}>
                        {label}
                    </span>
                </label>
            );
        }

        # Select dropdown
        if fieldType == "select" {
            options = getEnumOptions(fieldSchema);
            watchValue = form.watch(fieldName);
            return (
                <select
                    name={field.name}
                    ref={field.ref}
                    onChange={field.onChange}
                    onBlur={field.onBlur}
                    value={watchValue || ""}
                    className={inputClassName}
                    style={{width: "100%", boxSizing: "border-box"}}
                >
                    <option value="">
                        {placeholder or f"Select {label}"}
                    </option>
                    {options.map(
                        lambda opt: any  -> JsxElement { return
                            <option value={opt} key={opt}>
                                {opt}
                            </option>; }
                    )}
                </select>
            );
        }

        # Radio buttons
        if fieldType == "radio" {
            options = getEnumOptions(fieldSchema);
            watchValue = form.watch(fieldName);
            return (
                <div style={{display: "flex", flexDirection: "column", gap: "0.5rem"}}>
                    {options.map(
                        lambda opt: any  -> JsxElement { return (
                            <label
                                key={opt}
                                style={{
                                    cursor: "pointer",
                                    display: "flex",
                                    alignItems: "center",
                                    gap: "0.5rem"
                                }}
                            >
                                <input
                                    type="radio"
                                    name={field.name}
                                    value={opt}
                                    ref={field.ref}
                                    onChange={field.onChange}
                                    onBlur={field.onBlur}
                                    checked={watchValue == opt}
                                    className={inputClassName}
                                    style={{cursor: "pointer"}}
                                />
                                <span>
                                    {opt}
                                </span>
                            </label>
                        ); }
                    )}
                </div>
            );
        }

        # Textarea
        if fieldType == "textarea" {
            rows = config.rows or 4;
            return (
                <textarea
                    placeholder={placeholder}
                    rows={rows}
                    {...field}
                    className={inputClassName}
                    style={{
                        width: "100%",
                        boxSizing: "border-box",
                        border: ("2px solid #ef4444" if error else "2px solid #e5e7eb"),
                        padding: "0.5rem",
                        fontFamily: "inherit",
                        fontSize: "inherit",
                        resize: "vertical"
                    }}
                />
            );
        }

        # Regular input (text, email, password, number, date, datetime-local, tel, url, etc.)
        # Special handling for password fields with visibility toggle
        if fieldType == "password" and config.showPasswordToggle {
            isVisible = passwordVisible[fieldName] || False;
            return (
                <div>
                    <div style={{position: "relative"}}>
                        <input
                            type={"text" if isVisible else "password"}
                            placeholder={placeholder}
                            {...field}
                            className={inputClassName}
                            style={{
                                width: "100%",
                                boxSizing: "border-box",
                                border: (
                                    "2px solid #ef4444"
                                        if error
                                        else "2px solid #e5e7eb"
                                ),
                                paddingRight: "2.5rem"
                            }}
                        />
                    </div>
                    <label
                        style={{
                            cursor: "pointer",
                            display: "flex",
                            alignItems: "center",
                            gap: "0.5rem",
                            marginTop: "0.5rem",
                            fontSize: "0.875rem",
                            color: "#6b7280"
                        }}
                    >
                        <input
                            type="checkbox"
                            checked={isVisible}
                            onChange={lambda e: any  -> None { setPasswordVisible(
                                lambda prev: any  -> dict { newState = Object.assign(
                                    {}, prev
                                );newState[fieldName] = not isVisible;return newState; }
                            );}}
                            style={{cursor: "pointer"}}
                        />
                        <span>
                            Show password
                        </span>
                    </label>
                </div>
            );
        }

        # Regular input without toggle
        return (
            <input
                type={fieldType}
                placeholder={placeholder}
                {...field}
                className={inputClassName}
                style={{
                    width: "100%",
                    boxSizing: "border-box",
                    border: ("2px solid #ef4444" if error else "2px solid #e5e7eb")
                }}
            />
        );
    }
    # Main field renderer
    def renderField(fieldName: str) -> JsxElement {
        fieldSchema = schemaShape[fieldName];
        config = field_config[fieldName] if field_config[fieldName] else {};

        # Note: "type" gets compiled to "key" in JavaScript to avoid conflicts with React's type prop
        fieldType = config.key or "text";
        label = config.label or fieldName;
        fieldClassName = config.className or "";
        labelClassName = config.labelClassName or "";

        # Register field and get error state
        # valueAsNumber: true is required for number fields because <input type="number">
        registerOptions = {"valueAsNumber": True} if fieldType == "number" else {};
        field = form.register(fieldName, registerOptions);
        error = errors[fieldName];

        # Render: wrapper > input > error
        return (
            <div
                className={fieldClassName}
                style={{marginBottom: "1rem"}}
                key={fieldName}
            >
                <label
                    className={labelClassName}
                    style={{display: "block", marginBottom: "0.5rem"}}
                >
                    {label}
                </label>
                {renderInput(fieldType, field, error, config, fieldSchema, fieldName)}
                {renderError(error)}
            </div>
        );
    }
    # Generate layout styles based on layout prop
    def getLayoutStyle -> dict {
        if layout == "grid" {
            return {
                display: "grid",
                gridTemplateColumns: f"repeat({gridColumns}, 1fr)",
                gap: "1rem"
            };
        } elif layout == "horizontal" {
            return {
                display: "flex",
                gap: "1rem",
                flexWrap: "wrap",
                alignItems: "flex-start"
            };
        } elif layout == "inline" {
            return {display: "flex", gap: "0.5rem", alignItems: "flex-end"};
        } else {
            # vertical (default)
            return {};
        }
    }
    # Render all fields
    fields = [];
    for fieldName in fieldNames {
        fields.append(renderField(fieldName));
    }
    layoutStyle = getLayoutStyle();
    formClassName = className or "";
    buttonClassName = submitClassName or "";
    return (
        <form onSubmit={form.handleSubmit(onSubmit)} className={formClassName}>
            <div style={layoutStyle}>
                {fields}
            </div>
            <button
                type="submit"
                disabled={isSubmitting or not isDirty}
                className={buttonClassName}
                style={{
                    width: "100%",
                    cursor: (
                        "not-allowed" if (isSubmitting or not isDirty) else "pointer"
                    )
                }}
            >
                {isSubmitting and "Submitting..."}{not isSubmitting and submitLabel}
            </button>
        </form>
    );
}
