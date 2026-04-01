impl __jacJsx(tag: Any, props: dict = {}, children: list = []) -> JsxElement {
    return JsxElement(tag=tag, props=props, children=children);
}

impl renderJsxTree(nd: JsxElement, container: Any) -> None {
    container.replaceChildren(__buildDom(nd));
}

impl __buildDom(nd: Any) -> Any {
    if nd == None {
        return document.createTextNode("");
    }
    # Handle arrays (from .map() calls) - return a document fragment
    if Array.isArray(nd) {
        fragment = document.createDocumentFragment();
        for item in nd {
            childDom = __buildDom(item);
            if childDom {
                fragment.appendChild(childDom);
            }
        }
        return fragment;
    }
    if not __isObject(nd) {
        return document.createTextNode(str(nd));
    }
    # Handle component functions
    tag = nd.tag;
    if __isFunction(tag) {
        props = nd.props;
        children = nd.children;
        # Merge children into props for component
        if children and len(children) > 0 {
            props["children"] = children;
        }
        return __buildDom(tag(props));
    }
    # Create element
    element = document.createElement(tag or "div");
    # Apply properties
    props = nd.props;
    for key in __objectKeys(props) {
        value = props.get(key);
        __applyProp(element, key, value);
    }
    # Render children
    children = nd.children;
    for child in children {
        childDom = __buildDom(child);
        if childDom {
            element.appendChild(childDom);
        }
    }
    return element;
}

impl __applyProp(element: Any, key: str, value: Any) -> None {
    if key.startswith("on") {
        # Event handler: onclick -> click
        event = key[2:].lower();
        element.addEventListener(event, value);
    } elif key == "className" or key == "class" {
        element.className = value;
    } elif key == "style" and __isObject(value) {
        # Style object
        for styleKey in __objectKeys(value) {
            element.style[styleKey] = value[styleKey];
        }
    } elif key == "checked"
    or key == "disabled"
    or key == "readonly"
    or key == "selected" {
        # Boolean attributes - use property instead of attribute
        element[key] = bool(value);
    } elif key == "value" {
        # Value property for form elements
        element.value = value;
    } elif key != "children" {
        element.setAttribute(key, str(value));
    }
}

impl createSignal(initialValue: Any) -> list {
    signalId = len(__jacReactiveContext.signals);
    signalData = {"value": initialValue, "subscribers": []};
    __jacReactiveContext.signals.append(signalData);
    def getter -> Any {
        __jacTrackDependency(signalData.subscribers);
        return signalData.value;
    }
    def setter(newValue: Any) -> None {
        if newValue != signalData.value {
            signalData.value = newValue;
            __jacNotifySubscribers(signalData.subscribers);
        }
    }
    return [getter, setter];
}

impl createState(initialState: dict) -> list {
    signalId = len(__jacReactiveContext.signals);
    signalData = {"value": initialState, "subscribers": []};
    __jacReactiveContext.signals.append(signalData);
    def getter -> dict {
        __jacTrackDependency(signalData.subscribers);
        return signalData.value;
    }
    def setter(updates: dict) -> None {
        # Shallow merge
        newState = {};
        stateValue = signalData.value;
        for key in __objectKeys(stateValue) {
            newState[key] = stateValue[key];
        }
        for key in __objectKeys(updates) {
            newState[key] = updates[key];
        }
        signalData.value = newState;
        __jacNotifySubscribers(signalData.subscribers);
    }
    return [getter, setter];
}

impl createEffect(effectFn: Any) -> None {
    __jacRunEffect(effectFn);
}

impl onMount(mountFn: Any) -> None {
    currentComponent = __jacReactiveContext.currentComponent;
    if not currentComponent {
        # Not in a component context, run immediately
        __jacRunEffect(mountFn);
        return;
    }
    # Track mounted components
    if not __jacReactiveContext.mountedComponents {
        __jacReactiveContext.mountedComponents = {};
    }
    # Check if this component has already mounted
    componentId = f"{currentComponent}";
    if not __jacHasOwn(__jacReactiveContext.mountedComponents, componentId) {
        # Mark as mounted and run the effect
        __jacReactiveContext.mountedComponents[componentId] = True;
        # Run in next tick to ensure component is fully rendered
        try {
            setTimeout(lambda -> None { __jacRunEffect(mountFn);}, 0);
        } except Exception {
            # Fallback if setTimeout not available
            __jacRunEffect(mountFn);
        }
    }
}

impl __jacTrackDependency(subscribers: list) -> None {
    currentEffect = __jacReactiveContext.currentEffect;
    if currentEffect {
        alreadySubscribed = False;
        for sub in subscribers {
            if sub == currentEffect {
                alreadySubscribed = True;
            }
        }
        if not alreadySubscribed {
            subscribers.append(currentEffect);
        }
    }
    currentComponent = __jacReactiveContext.currentComponent;
    if currentComponent {
        alreadySubscribed = False;
        for sub in subscribers {
            if sub == currentComponent {
                alreadySubscribed = True;
            }
        }
        if not alreadySubscribed {
            subscribers.append(currentComponent);
        }
    }
}

impl __jacNotifySubscribers(subscribers: list) -> None {
    for subscriber in subscribers {
        if __isFunction(subscriber) {
            # It's an effect function - re-run it
            __jacRunEffect(subscriber);
        } else {
            # It's a component ID - schedule re-render
            __jacScheduleRerender(subscriber);
        }
    }
}

impl __jacRunEffect(effectFn: Any) -> None {
    previousEffect = __jacReactiveContext.currentEffect;
    __jacReactiveContext.currentEffect = effectFn;
    try {
        effectFn();
    } except Exception as err {
        console.error("[Jac] Error in effect:", err);
    }
    __jacReactiveContext.currentEffect = previousEffect;
}

impl __jacScheduleRerender(componentId: Any) -> None {
    pending = __jacReactiveContext.pendingRenders;
    # Check if already scheduled
    alreadyScheduled = False;
    for item in pending {
        if item == componentId {
            alreadyScheduled = True;
        }
    }
    if not alreadyScheduled {
        pending.append(componentId);
        __jacScheduleFlush();
    }
}

impl __jacScheduleFlush -> None {
    if not __jacReactiveContext.flushScheduled {
        __jacReactiveContext.flushScheduled = True;
        # Use requestAnimationFrame for batching, fallback to setTimeout
        try {
            requestAnimationFrame(__jacFlushRenders);
        } except Exception {
            setTimeout(__jacFlushRenders, 0);
        }
    }
}

impl __jacFlushRenders -> None {
    pending = __jacReactiveContext.pendingRenders;
    __jacReactiveContext.pendingRenders = [];
    __jacReactiveContext.flushScheduled = False;
    for componentId in pending {
        __jacRerenderComponent(componentId);
    }
}

impl __jacRerenderComponent(componentId: Any) -> None {
    rootEl = document.getElementById("__jac_root");
    if not rootEl {
        return;
    }
    rootComponent = __jacReactiveContext.rootComponent;
    if not rootComponent {
        return;
    }
    try {
        previousComponent = __jacReactiveContext.currentComponent;
        __jacReactiveContext.currentComponent = componentId;
        # Reset hook index for useState tracking
        __jacReactiveContext.hookIndex = 0;

        component = rootComponent();
        renderJsxTree(component, rootEl);

        __jacReactiveContext.currentComponent = previousComponent;
    } except Exception as err {
        console.error("[Jac] Error re-rendering component:", err);
    }
}

impl createRouter(routes: list, defaultRoute: str = "/") -> dict {
    # Get initial path from URL pathname or use default
    initialPath = __jacGetPath();
    if not initialPath or initialPath == "/" {
        initialPath = defaultRoute;
    }
    # Create reactive signal for current path
    [currentPath, setCurrentPath] = createSignal(initialPath);
    # Listen to popstate (back/forward buttons and pushState navigation)
    window.addEventListener(
        "popstate",
        lambda event: Any -> None { newPath = __jacGetPath();if not newPath {
            newPath = defaultRoute;
        }setCurrentPath(newPath);}
    );
    # Render method - returns component for current route
    def render -> JsxElement {
        path = currentPath();  # Track dependency!

        # Find matching route
        for route in routes {
            if route.path == path {
                # Check guard if present
                if route.guard and not route.guard() {
                    return
                        <div>
                            Access Denied
                        </div>;
                }
                return route.component();
            }
        }

        # No match - show 404
        return
            <div>
                404 - Route not found:{path}
            </div>;
    }
    # Navigate method
    def navigateTo(path: str) -> None {
        window.history.pushState({}, "", path);
        setCurrentPath(path);
    }
    # Store router in global context
    router = {"path": currentPath, "render": render, "navigate": navigateTo};
    __jacReactiveContext.router = router;
    return router;
}

impl Route(path: str, component: Any, guard: Any = None) -> dict {
    return {"path": path, "component": component, "guard": guard};
}

impl Link(props: dict) -> JsxElement {
    href = props["href"] if "href" in props else "/";
    children = props["children"] if "children" in props else [];
    def handleClick(event: Any) -> None {
        event.preventDefault();
        navigate(href);
    }
    # Return JSX node manually to properly spread children
    return __jacJsx("a", {"href": href, "onclick": handleClick}, children);
}

impl navigate(path: str) -> None {
    router = __jacReactiveContext.router;
    if router {
        router.navigate(path);
    } else {
        window.history.pushState({}, "", path);
        window.dispatchEvent(Reflect.construct(PopStateEvent, ["popstate"]));
    }
}

impl useRouter -> dict {
    return __jacReactiveContext.router;
}

impl __jacGetPath -> str {
    pathname = window.location.pathname;
    if pathname {
        return pathname;
    }
    return "/";
}

impl __jacSpawn(left: str, right: str = "", fields: dict = {}) -> Any {
    token = __getLocalStorage("jac_token");
    url = f"/walker/{left}";
    if right != "" {
        url = f"/walker/{left}/{right}";
    }
    response = await fetch(
        url,
        {
            "method": "POST",
            "accept": "application/json",
            "headers": {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}" if token else ""
            },
            "body": JSON.stringify(fields)
        }
    );
    if not response.ok {
        error_text = await response.json();
        walker_name = f"{left}/{right}" if right else left;
        raise Exception(f"Walker {walker_name} failed: {error_text}");
    }
    payload = await response.json();
    # Handle TransportResponse envelope format
    return payload["data"] if payload["data"] else payload;
}

impl __jacCallFunction(function_name: str, args: dict = {}) -> Any {
    token = __getLocalStorage("jac_token");
    response = await fetch(
        f"/function/{function_name}",
        {
            "method": "POST",
            "headers": {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}" if token else ""
            },
            "body": JSON.stringify(args)
        }
    );
    if not response.ok {
        error_text = await response.text();
        raise Exception(f"Function {function_name} failed: {error_text}");
    }
    payload = JSON.parse(await response.text());
    # Handle TransportResponse envelope format
    response_data = payload["data"] if payload["data"] else payload;
    result = None;
    try {
        if response_data["result"] {
            result = response_data["result"];
        }
    } except Exception { }
    return result;
}

impl jacSignup(username: str, password: str) -> dict {
    response = await fetch(
        "/user/create",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"username": username, "password": password})
        }
    );
    if response.ok {
        payload = JSON.parse(await response.text());
        # Handle TransportResponse envelope format
        response_data = payload["data"] if payload["data"] else payload;
        token = None;
        try {
            if response_data["token"] {
                token = response_data["token"];
            }
        } except Exception { }
        if token {
            __setLocalStorage("jac_token", token);
            return {"success": True, "token": token, "username": username};
        }
        return {"success": False, "error": "No token received"};
    } else {
        error_text = await response.text();
        try {
            error_payload = JSON.parse(error_text);
            # Handle TransportResponse envelope format
            error_data = error_payload["data"]
                if error_payload["data"]
                else error_payload;
            error_msg = None;
            try {
                if error_data["error"] {
                    error_msg = error_data["error"];
                }
            } except Exception { }
            return {"success": False, "error": error_msg or "Signup failed"};
        } except Exception {
            return {"success": False, "error": error_text};
        }
    }
}

impl jacLogin(username: str, password: str) -> bool {
    response = await fetch(
        "/user/login",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"username": username, "password": password})
        }
    );
    if response.ok {
        payload = JSON.parse(await response.text());
        # Handle TransportResponse envelope format
        response_data = payload["data"] if payload["data"] else payload;
        token = None;
        try {
            if response_data["token"] {
                token = response_data["token"];
            }
        } except Exception { }
        if token {
            __setLocalStorage("jac_token", token);
            return True;
        }
    }
    return False;
}

impl jacLogout -> None {
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

impl __isObject(value: Any) -> bool {
    if value == None {
        return False;
    }
    return Object.prototype.toString.call(value) == "[object Object]";
}

impl __isFunction(value: Any) -> bool {
    return Object.prototype.toString.call(value) == "[object Function]";
}

impl __objectKeys(`obj: Any) -> list {
    if `obj == None {
        return [];
    }
    return Object.keys(`obj);
}

impl __jacHasOwn(`obj: Any, key: Any) -> bool {
    try {
        return Object.prototype.hasOwnProperty.call(`obj, key);
    } except Exception {
        return False;
    }
}

impl __jacEnsureObjectGetPolyfill -> None {
    proto = Object.prototype;
    if proto.get {
        return;
    }
    # Define the polyfill function inline
    def get_polyfill(key: Any, defaultValue: Any = None) -> Any {
        if __jacHasOwn(this, key) {
            return this[key];
        }
        if defaultValue != None {
            return defaultValue;
        }
        return None;
    }
    Object.defineProperty(
        proto, "get", {"value": get_polyfill, "configurable": True, "writable": True}
    );
}

impl __jacGetDocument(scope: Any) -> Any {
    try {
        return scope.document;
    } except Exception {
        return None;
    }
}

impl __jacParseJsonObject(text: str) -> Any {
    try {
        parsed = JSON.parse(text);
        if __isObject(parsed) {
            return parsed;
        }
        console.error("[Jac] Hydration payload is not an object");
        return None;
    } except Exception as err {
        console.error("[Jac] Failed to parse hydration payload", err);
        return None;
    }
}

impl __jacBuildOrderedArgs(order: list, argsDict: dict) -> list {
    result = [];
    if not order {
        return result;
    }
    values = argsDict if __isObject(argsDict) else {};
    for name in order {
        result.append(values.get(name));
    }
    return result;
}

impl __jacResolveRenderer(scope: Any) -> Any {
    if scope.renderJsxTree {
        return scope.renderJsxTree;
    }
    if __isFunction(renderJsxTree) {
        return renderJsxTree;
    }
    return None;
}

impl __jacResolveTarget(moduleRecord: dict, registry: dict, name: str) -> Any {
    moduleFunctions = (
        moduleRecord.moduleFunctions
            if moduleRecord and moduleRecord.moduleFunctions
            else {}
    );
    if __jacHasOwn(moduleFunctions, name) {
        return moduleFunctions[name];
    }
    registryFunctions = registry.functions if registry and registry.functions else {};
    if __jacHasOwn(registryFunctions, name) {
        return registryFunctions[name];
    }
    return None;
}

impl __jacSafeCallTarget(
    target: Any, scope: Any, orderedArgs: list, targetName: str
) -> dict {
    try {
        result = target.apply(scope, orderedArgs);
        return {"ok": True, "value": result};
    } except Exception as err {
        console.error("[Jac] Error executing client function " + targetName, err);
        return {"ok": False, "value": None};
    }
}

impl __jacGlobalScope -> Any {
    try {
        return globalThis;
    } except Exception { }
    try {
        return window;
    } except Exception { }
    try {
        return self;
    } except Exception { }
    return {};
}

impl __jacEnsureRegistry -> dict {
    scope = __jacGlobalScope();
    registry = scope.__jacClient;
    if not registry {
        registry = {
            "functions": {},
            "globals": {},
            "modules": {},
            "state": {"globals": {}},
            "__hydration": {"registered": False},
            "lastModule": None
        };
        scope.__jacClient = registry;
        return registry;
    }
    if not registry.functions {
        registry.functions = {};
    }
    if not registry.globals {
        registry.globals = {};
    }
    if not registry.modules {
        registry.modules = {};
    }
    if not registry.state {
        registry.state = {"globals": {}};
    } elif not registry.state.globals {
        registry.state.globals = {};
    }
    if not registry.__hydration {
        registry.__hydration = {"registered": False};
    }
    return registry;
}

impl __jacApplyRender(renderer: Any, container: Any, nd: Any) -> None {
    if not renderer or not container {
        return;
    }
    try {
        renderer(nd, container);
    } except Exception as err {
        console.error("[Jac] Failed to render JSX tree", err);
    }
}

impl __jacHydrateFromDom(defaultModuleName: str) -> None {
    __jacEnsureObjectGetPolyfill();
    scope = __jacGlobalScope();
    documentRef = __jacGetDocument(scope);
    if not documentRef {
        return;
    }
    initEl = documentRef.getElementById("__jac_init__");
    rootEl = documentRef.getElementById("__jac_root");
    if not initEl or not rootEl {
        return;
    }
    dataset = initEl.dataset or None;
    if dataset and dataset.jacHydrated == "true" {
        return;
    }
    if dataset {
        dataset.jacHydrated = "true";
    }
    payloadText = initEl.textContent or "{}";
    payload = __jacParseJsonObject(payloadText);
    if not payload {
        return;
    }
    targetName = payload.get("function");
    if not targetName {
        return;
    }
    fallbackModule = defaultModuleName or "";
    moduleCandidate = payload.get("module");
    moduleName = moduleCandidate or fallbackModule;
    registry = __jacEnsureRegistry();
    modulesStore = registry.modules or {};
    moduleRecord = modulesStore[moduleName]
        if __jacHasOwn(modulesStore, moduleName)
        else None;
    if not moduleRecord {
        console.error("[Jac] Client module not registered: " + moduleName);
        return;
    }
    argOrderRaw = payload.get("argOrder", []);
    argOrder = argOrderRaw if Array.isArray(argOrderRaw) else [];
    argsDictRaw = payload.get("args", {});
    argsDict = argsDictRaw if __isObject(argsDictRaw) else {};
    orderedArgs = __jacBuildOrderedArgs(argOrder, argsDict);
    payloadGlobalsRaw = payload.get("globals", {});
    payloadGlobals = payloadGlobalsRaw if __isObject(payloadGlobalsRaw) else {};
    registry.state.globals[moduleName] = payloadGlobals;
    for gName in __objectKeys(payloadGlobals) {
        gValue = payloadGlobals[gName];
        scope[gName] = gValue;
        registry.globals[gName] = gValue;
    }
    target = __jacResolveTarget(moduleRecord, registry, targetName);
    if not target {
        console.error("[Jac] Client function not found: " + targetName);
        return;
    }
    # Set up reactive root component for automatic re-rendering
    __jacReactiveContext.rootComponent = lambda -> Any { __jacReactiveContext.currentComponent = "__root__";result = target.apply(
        scope, orderedArgs
    );__jacReactiveContext.currentComponent = None;return result; };
    renderer = __jacResolveRenderer(scope);
    if not renderer {
        console.warn("[Jac] renderJsxTree is not available in client bundle");
    }
    # Initial render - reset hook index and call the root component
    __jacReactiveContext.hookIndex = 0;
    value = __jacReactiveContext.rootComponent();
    if value and __isObject(value) and __isFunction(value.then) {
        value.then(
            lambda nd: Any -> None { __jacApplyRender(renderer, rootEl, nd);}
        ).catch(
            lambda err: Any -> None { console.error(
                "[Jac] Error resolving client function promise", err
            );}
        );
    } else {
        __jacApplyRender(renderer, rootEl, value);
    }
}

impl __jacExecuteHydration -> None {
    registry = __jacEnsureRegistry();
    defaultModule = registry.lastModule or "";
    __jacHydrateFromDom(defaultModule);
}

impl __jacEnsureHydration(moduleName: str) -> None {
    __jacEnsureObjectGetPolyfill();
    registry = __jacEnsureRegistry();
    registry.lastModule = moduleName;
    existingHydration = registry.__hydration or None;
    hydration = existingHydration or {"registered": False};
    registry.__hydration = hydration;
    scope = __jacGlobalScope();
    documentRef = __jacGetDocument(scope);
    if not documentRef {
        return;
    }
    alreadyRegistered = hydration.registered or False;
    if not alreadyRegistered {
        hydration.registered = True;
        documentRef.addEventListener(
            "DOMContentLoaded",
            lambda _event: Any -> None { __jacExecuteHydration();},
            {"once": True}
        );
    }
    if documentRef.readyState != "loading" {
        __jacExecuteHydration();
    }
}

impl __jacRegisterClientModule(
    moduleName: str, clientFunctions: list = [], clientGlobals: dict = {}
) -> None {
    __jacEnsureObjectGetPolyfill();
    __jacInstallErrorHandlers();
    scope = __jacGlobalScope();
    registry = __jacEnsureRegistry();
    moduleFunctions = {};
    registeredFunctions = [];
    if clientFunctions {
        for funcName in clientFunctions {
            funcRef = scope[funcName];
            if not funcRef {
                console.error(
                    "[Jac] Client function not found during registration: " + funcName
                );
                continue;
            }
            moduleFunctions[funcName] = funcRef;
            registry.functions[funcName] = funcRef;
            scope[funcName] = funcRef;
            registeredFunctions.append(funcName);
        }
    }
    moduleGlobals = {};
    globalNames = [];
    globalsMap = clientGlobals or {};
    for gName in __objectKeys(globalsMap) {
        globalNames.append(gName);
        defaultValue = globalsMap[gName];
        existing = scope[gName];
        if existing == None {
            scope[gName] = defaultValue;
            moduleGlobals[gName] = defaultValue;
        } else {
            moduleGlobals[gName] = existing;
        }
        registry.globals[gName] = scope[gName];
    }
    modulesStore = registry.modules or {};
    existingRecord = modulesStore[moduleName]
        if __jacHasOwn(modulesStore, moduleName)
        else None;
    moduleRecord = existingRecord or {};
    moduleRecord.moduleFunctions = moduleFunctions;
    moduleRecord.moduleGlobals = moduleGlobals;
    moduleRecord.functions = registeredFunctions;
    moduleRecord.globals = globalNames;
    moduleRecord.defaults = globalsMap;
    registry.modules[moduleName] = moduleRecord;
    stateGlobals = registry.state.globals;
    if not __jacHasOwn(stateGlobals, moduleName) {
        stateGlobals[moduleName] = {};
    }
    __jacEnsureHydration(moduleName);
}

# ============================================================================
# React-style API aliases
# ============================================================================
"""useState - React-compatible state hook.
Returns [value, setter] where value is the current state (not a getter function).
When setter is called, schedules a re-render of the component.
Uses hook index tracking to maintain state across re-renders.
"""
impl useState(initialValue: Any) -> list {
    # Get current hook index
    hookIndex = __jacReactiveContext.hookIndex;
    hooks = __jacReactiveContext.hooks;
    # Check if this hook already exists (re-render) or needs to be created (first render)
    if hookIndex < len(hooks) {
        # Re-render: return existing state
        hookData = hooks[hookIndex];
        __jacReactiveContext.hookIndex = hookIndex + 1;
        return [hookData.value, hookData.setter];
    }
    # First render: create new state
    signalData = {"value": initialValue};
    # Setter that updates value and triggers re-render
    def setter(newValue: Any) -> None {
        if newValue != signalData.value {
            signalData.value = newValue;
            # Schedule re-render of root component
            __jacScheduleRerender("__root__");
        }
    }
    # Store in hooks array for subsequent renders
    signalData["setter"] = setter;
    hooks.append(signalData);
    __jacReactiveContext.hookIndex = hookIndex + 1;
    # Return current value and setter
    return [signalData.value, setter];
}

"""useEffect - React-compatible effect hook.
When deps is empty [], runs once on mount (like onMount).
Otherwise tracks dependencies and re-runs when they change.
"""
impl useEffect(effectFn: Any, deps: list = []) -> None {
    # For now, always run on mount since we don't have React's dep tracking
    # This matches useEffect(() => { ... }, []) behavior
    onMount(effectFn);
}

# ============================================================================
# Client Error Reporting
# ============================================================================
"""Report a client-side error to the server via POST /cl/__error__.
Fires asynchronously and silently ignores failures (to avoid error loops).
"""
impl __jacReportError(
    message: str, stack: str = "", url: str = "", source: str = ""
) -> None {
    try {
        fetch(
            "/cl/__error__",
            {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify(
                    {
                        "message": message,
                        "stack": stack,
                        "url": url or window.location.href,
                        "source": source,
                        "timestamp": Reflect.construct(Date, []).toISOString()
                    }
                )
            }
        );
    } except Exception {
    # Silently ignore - never let error reporting cause more errors
    }
}

"""Install global error handlers to catch unhandled JS errors and rejections.
Called once during client module initialization.
"""
impl __jacInstallErrorHandlers -> None {
    scope = __jacGlobalScope();
    if not scope or not scope.addEventListener {
        return;
    }
    # Guard against double-install
    if scope.__jacErrorHandlersInstalled {
        return;
    }
    scope.__jacErrorHandlersInstalled = True;
    # Catch synchronous errors (e.g., TypeError, ReferenceError)
    scope.addEventListener(
        "error",
        lambda event: Any -> None { __jacReportError(
            event.message or "Unknown error",
            event.error.stack if event.error else "",
            event.filename or "",
            "window.onerror"
        );}
    );
    # Catch unhandled promise rejections (e.g., failed fetch, async errors)
    scope.addEventListener(
        "unhandledrejection",
        lambda event: Any -> None { reason = event.reason;message = "";stack = "";if reason {
            message = reason.message or str(reason);
            stack = reason.stack or "";
        } else {
            message = "Unhandled promise rejection";
        } __jacReportError(message, stack, "", "unhandledrejection");}
    );
}
