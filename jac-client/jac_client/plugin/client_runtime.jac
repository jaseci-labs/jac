"""Client-side runtime for Jac JSX and walker interactions."""

cl import from 'react' {* as React}
cl import from 'react-dom/client' {* as ReactDOM}

cl {
# JSX factory function - uses React.createElement
def __jacJsx(tag: any, props: dict = {}, children: any = []) -> any {
    # Handle fragments: when tag is None/null, use React.Fragment
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

    # Filter out null/undefined children
    reactChildren = [];
    for child in childrenArray {
        if child != None {
            reactChildren.push(child);
        }
    }

    if reactChildren.length > 0 {
        args = [tag, props];
        for child in reactChildren {
            args.push(child);
        }
        return React.createElement.apply(React, args);
    } else {
        return React.createElement(tag, props);
    }
}

def renderJsxTree(node: any, container: any) -> None {
    try {
        ReactDOM.createRoot(container).render(node);
    } except Exception as err {
        console.error("[Jac] Error in renderJsxTree:", err);
    }
}

# ============================================================================
# Reactive State Management System
# ============================================================================

# Global reactive context for managing signals, effects, and re-renders
let __jacReactiveContext = {
    "signals": [],              # Global signal storage (enables closures)
    "pendingRenders": [],       # Batched re-renders queue
    "flushScheduled": False,    # Debounce flag for batching
    "rootComponent": None,      # Root function to re-render
    "reactRoot": None,          # Store the React 18 root instance
    "currentComponent": None,   # Current component ID being rendered
    "currentEffect": None,      # Current effect for dependency tracking
    "router": None,            # Global router instance
    "mountedComponents": {}     # Track which components have mounted (for onMount)
};

# Create a reactive signal (primitive value)
# Returns [getter, setter] tuple for reactive primitive value
def createSignal(initialValue: any) -> list {
    signalId = __jacReactiveContext.signals.length;
    signalData = {"value": initialValue, "subscribers": []};
    __jacReactiveContext.signals.push(signalData);

    def getter() -> any {
        __jacTrackDependency(signalData.subscribers);
        return signalData.value;
    }

    def setter(newValue: any) -> None {
        if newValue != signalData.value {
            signalData.value = newValue;
            __jacNotifySubscribers(signalData.subscribers);
        }
    }

    return [getter, setter];
}

# Create reactive state (object/dict)
# Returns [getter, setter] tuple for reactive object
def createState(initialState: dict) -> list {
    signalId = __jacReactiveContext.signals.length;
    signalData = {"value": initialState, "subscribers": []};
    __jacReactiveContext.signals.push(signalData);

    def getter() -> dict {
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

# Run effect when dependencies change
# Executes effectFn and re-runs when tracked signals change
def createEffect(effectFn: any) -> None {
    __jacRunEffect(effectFn);
}

# Run effect once when component mounts (similar to useEffect with empty deps)
# Executes mountFn once when the component first renders
def onMount(mountFn: any) -> None {
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
            setTimeout(lambda -> None {
                __jacRunEffect(mountFn);
            }, 0);
        } except Exception {
            # Fallback if setTimeout not available
            __jacRunEffect(mountFn);
        }
    }
}

# Internal: Track component dependencies
def __jacTrackDependency(subscribers: list) -> None {
    currentEffect = __jacReactiveContext.currentEffect;
    if currentEffect {
        alreadySubscribed = False;
        for sub in subscribers {
            if sub == currentEffect {
                alreadySubscribed = True;
            }
        }
        if not alreadySubscribed {
            subscribers.push(currentEffect);
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
            subscribers.push(currentComponent);
        }
    }
}

# Internal: Notify subscribers of state change
def __jacNotifySubscribers(subscribers: list) -> None {
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

# Internal: Run an effect function with dependency tracking
def __jacRunEffect(effectFn: any) -> None {
    previousEffect = __jacReactiveContext.currentEffect;
    __jacReactiveContext.currentEffect = effectFn;

    try {
        effectFn();
    } except Exception as err {
        console.error("[Jac] Error in effect:", err);
    }

    __jacReactiveContext.currentEffect = previousEffect;
}

# Schedule a re-render (batched)
def __jacScheduleRerender(componentId: any) -> None {
    pending = __jacReactiveContext.pendingRenders;

    # Check if already scheduled
    alreadyScheduled = False;
    for item in pending {
        if item == componentId {
            alreadyScheduled = True;
        }
    }

    if not alreadyScheduled {
        pending.push(componentId);
        __jacScheduleFlush();
    }
}

# Schedule a flush of pending renders
def __jacScheduleFlush() -> None {
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

# Flush all pending renders
def __jacFlushRenders() -> None {
    pending = __jacReactiveContext.pendingRenders;
    __jacReactiveContext.pendingRenders = [];
    __jacReactiveContext.flushScheduled = False;

    for componentId in pending {
        __jacRerenderComponent(componentId);
    }
}

# Re-render the root component
def __jacRerenderComponent(componentId: any) -> None {
    # Use the stored React 18 root for re-rendering
    reactRoot = __jacReactiveContext.reactRoot;
    if not reactRoot {
        console.error("[Jac] React root not initialized. Cannot re-render.");
        return;
    }

    rootComponent = __jacReactiveContext.rootComponent;
    if not rootComponent {
        return;
    }

    try {
        previousComponent = __jacReactiveContext.currentComponent;
        __jacReactiveContext.currentComponent = componentId;

        component = rootComponent();

        # FIXED: Use the stored React 18 root's render method
        reactRoot.render(component);

        __jacReactiveContext.currentComponent = previousComponent;
    } except Exception as err {
        console.error("[Jac] Error re-rendering component:", err);
    }
}

# ============================================================================
# Declarative Routing System
# ============================================================================

# Route configuration object
obj RouteConfig {
    has path: str;
    has component: any;
    has guard: any = None;
}

# Create a router instance
def initRouter(routes: list, defaultRoute: str = "/") -> dict {
    # Get initial path from hash or use default
    initialPath = __jacGetHashPath();
    if not initialPath {
        initialPath = defaultRoute;
    }

    # Create reactive signal for current path
    [currentPath, setCurrentPath] = createSignal(initialPath);

    # Listen to hash changes
    window.addEventListener("hashchange", lambda event: any -> None {
        newPath = __jacGetHashPath();
        if not newPath {
            newPath = defaultRoute;
        }
        setCurrentPath(newPath);
    });

    # Listen to popstate (back/forward buttons)
    window.addEventListener("popstate", lambda event: any -> None {
        newPath = __jacGetHashPath();
        if not newPath {
            newPath = defaultRoute;
        }
        setCurrentPath(newPath);
    });

    # Render method - returns component for current route
    def render() -> any {
        path = currentPath();  # Track dependency!

        # Find matching route
        for route in routes {
            if route.path == path {
                # Check guard if present
                if route.guard and not route.guard() {
                    return __jacJsx("div", {}, ["Access Denied"]);
                }
                return route.component();
            }
        }

        # No match - show 404
        return __jacJsx("div", {}, ["404 - Route not found: ", path]);
    }

    # Navigate method
    def navigateTo(path: str) -> None {
        window.location.hash = "#" + path;
        setCurrentPath(path);
    }

    # Store router in global context
    router = {
        "path": currentPath,
        "render": render,
        "navigate": navigateTo
    };
    __jacReactiveContext.router = router;

    return router;
}

# Route config factory
def Route(path: str, component: any, guard: any = None) -> dict {
    return {"path": path, "component": component, "guard": guard};
}

# Link component for declarative navigation
def Link(props: dict) -> any {
    href = props["href"] if "href" in props else "/";
    children = props["children"] if "children" in props else [];

    def handleClick(event: any) -> None {
        console.log("Link clicked, navigating to:", href);
        event.preventDefault();
        navigate(href);
    }

    # Ensure children is properly handled - convert to array if it's not already
    childrenArray = [];
    if children != None {
        if Array.isArray(children) {
            childrenArray = children;
        } else {
            childrenArray = [children];
        }
    }

    # Return JSX node manually to properly spread children
    return __jacJsx("a", {"href": "#" + href, "onclick": handleClick}, childrenArray);
}

# Navigate programmatically
def navigate(path: str) -> None {
    console.log("navigate() called with path:", path);
    router = __jacReactiveContext.router;
    if router {
        console.log("Router found, calling router.navigate()");
        router.navigate(path);
    } else {
        console.log("No router, setting hash directly");
        window.location.hash = "#" + path;
    }
}

# Hook to access router in components
def useRouter() -> dict {
    return __jacReactiveContext.router;
}

# Internal: Get current hash path
def __jacGetHashPath() -> str {
    hash = window.location.hash;
    if hash {
        return hash[1:];  # Remove '#'
    }
    return "";
}

# ============================================================================
# Walker spawn function
# ============================================================================

async def __jacSpawn(walker: str, fields: dict = {}, nd: str  | None = None) -> any {
    token = __getLocalStorage("jac_token");

    response = await fetch(
        f"/walker/{walker}",
        {
            "method": "POST",
            "headers": {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}" if token else ""
            },
            "body": JSON.stringify({"nd": nd if nd else "root", **fields})
        }
    );

    if not response.ok {
        error_text = await response.text();
        raise Exception(f"Walker {walker} failed: {error_text}");
    }

    return JSON.parse(await response.text());
}

# Function call function - calls server-side functions from client
async def __jacCallFunction(function_name: str, args: dict = {}) -> any {
    token = __getLocalStorage("jac_token");

    response = await fetch(
        f"/function/{function_name}",
        {
            "method": "POST",
            "headers": {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}" if token else ""
            },
            "body": JSON.stringify({"args": args})
        }
    );

    if not response.ok {
        error_text = await response.text();
        raise Exception(f"Function {function_name} failed: {error_text}");
    }

    data = JSON.parse(await response.text());
    return data["result"];
}

# Authentication helpers
async def jacSignup(username: str, password: str) -> dict {
    response = await fetch(
        "/user/create",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"username": username, "password": password})
        }
    );

    if response.ok {
        data = JSON.parse(await response.text());
        token = data["token"];
        if token {
            __setLocalStorage("jac_token", token);
            return {"success": True, "token": token, "username": username};
        }
        return {"success": False, "error": "No token received"};
    } else {
        error_text = await response.text();
        try {
            error_data = JSON.parse(error_text);
            return {"success": False, "error": error_data["error"] if error_data["error"] != None else "Signup failed"};
        } except Exception {
            return {"success": False, "error": error_text};
        }
    }
}

async def jacLogin(username: str, password: str) -> bool {
    response = await fetch(
        "/user/login",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"username": username, "password": password})
        }
    );

    if response.ok {
        data = JSON.parse(await response.text());
        token = data["token"];
        if token {
            __setLocalStorage("jac_token", token);
            return True;
        }
    }
    return False;
}

def jacLogout() -> None {
    __removeLocalStorage("jac_token");
}

def jacIsLoggedIn() -> bool {
    token = __getLocalStorage("jac_token");
    return token != None and token != "";
}

# Browser API shims
def __getLocalStorage(key: str) -> str {
    storage = globalThis.localStorage;
    return storage.getItem(key) if storage else "";
}

def __setLocalStorage(key: str, value: str) -> None {
    storage = globalThis.localStorage;
    if storage {
        storage.setItem(key, value);
    }
}

def __removeLocalStorage(key: str) -> None {
    storage = globalThis.localStorage;
    if storage {
        storage.removeItem(key);
    }
}

def __isObject(value: any) -> bool {
    if value == None {
        return False;
    }
    return Object.prototype.toString.call(value) == "[object Object]";
}

def __isFunction(value: any) -> bool {
    return Object.prototype.toString.call(value) == "[object Function]";
}

def __objectKeys(obj: any) -> list {
    if obj == None {
        return [];
    }
    return Object.keys(obj);
}

# Low-level helpers
def __jacHasOwn(obj: any, key: any) -> bool {
    try {
        return Object.prototype.hasOwnProperty.call(obj, key);
    } except Exception {
        return False;
    }
}

# Internal polyfill for Python-style dict.get on plain JS objects
def __jacEnsureObjectGetPolyfill() -> None {
    # No longer needed - we use standard JavaScript object access instead of .get() method
    return;
}

# Common utility helpers
def __jacGetDocument(scope: any) -> any {
    try {
        return scope.document;
    } except Exception {}
    try {
        return window.document;
    } except Exception {}
    return None;
}

def __jacParseJsonObject(text: str) -> any {
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

def __jacBuildOrderedArgs(order: list, argsDict: dict) -> list {
    result = [];
    if not order {
        return result;
    }
    values = argsDict if __isObject(argsDict) else {};
    for name in order {
        result.push(values[name]);
    }
    return result;
}

def __jacResolveRenderer(scope: any) -> any {
    if scope.renderJsxTree {
        return scope.renderJsxTree;
    }
    if __isFunction(renderJsxTree) {
        return renderJsxTree;
    }
    return None;
}

def __jacResolveTarget(
    moduleRecord: dict,
    registry: dict,
    name: str
) -> any {
    moduleFunctions = (
        moduleRecord.moduleFunctions
        if moduleRecord and moduleRecord.moduleFunctions
        else {}
    );
    if __jacHasOwn(moduleFunctions, name) {
        return moduleFunctions[name];
    }
    registryFunctions = (
        registry.functions
        if registry and registry.functions
        else {}
    );
    if __jacHasOwn(registryFunctions, name) {
        return registryFunctions[name];
    }
    return None;
}

def __jacSafeCallTarget(
    target: any,
    scope: any,
    orderedArgs: list,
    targetName: str
) -> dict {
    try {
        result = target.apply(scope, orderedArgs);
        return {"ok": True, "value": result};
    } except Exception as err {
        console.error("[Jac] Error executing client function " + targetName, err);
        return {"ok": False, "value": None};
    }
}

# Runtime support helpers for client module registration / hydration
def __jacGlobalScope() -> any {
    try {
        return globalThis;
    } except Exception {}
    try {
        return window;
    } except Exception {}
    try {
        return self;
    } except Exception {}
    return {};
}

def __jacEnsureRegistry() -> dict {
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

def __jacApplyRender(renderer: any, container: any, node: any) -> None {
    if not container {
        return;
    }
    try {
        # This function is now mostly legacy/fallback.
        # The main hydration path in __jacHydrateFromDom handles React 18.
        if renderer {
            renderer(node, container);
        } else {
            console.warn("[Jac] No JSX renderer available.");
        }
    } except Exception as err {
        console.error("[Jac] Failed to render JSX tree (fallback path)", err);
    }
}

def __jacHydrateFromDom(defaultModuleName: str) -> None {
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

    dataset = initEl.dataset if initEl.dataset else None;
    if dataset and dataset.jacHydrated == "true" {
        return;
    }
    if dataset {
        dataset.jacHydrated = "true";
    }

    payloadText = initEl.textContent if initEl.textContent else "{}";
    payload = __jacParseJsonObject(payloadText);
    if not payload {
        return;
    }

    targetName = payload["function"];
    if not targetName {
        return;
    }

    fallbackModule = defaultModuleName if defaultModuleName else "";
    moduleCandidate = payload["module"];
    moduleName = moduleCandidate if moduleCandidate else fallbackModule;

    registry = __jacEnsureRegistry();
    modulesStore = registry.modules if registry.modules else {};
    moduleRecord = modulesStore[moduleName] if __jacHasOwn(modulesStore, moduleName) else None;
    if not moduleRecord {
        console.error("[Jac] Client module not registered: " + moduleName);
        return;
    }

    argOrderRaw = payload["argOrder"] if payload["argOrder"] != None else [];
    argOrder = argOrderRaw if Array.isArray(argOrderRaw) else [];
    argsDictRaw = payload["args"] if payload["args"] != None else {};
    argsDict = argsDictRaw if __isObject(argsDictRaw) else {};
    orderedArgs = __jacBuildOrderedArgs(argOrder, argsDict);

    payloadGlobalsRaw = payload["globals"] if payload["globals"] != None else {};
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
    __jacReactiveContext.rootComponent = lambda -> any {
        __jacReactiveContext.currentComponent = "__root__";
        result = target.apply(scope, orderedArgs);
        __jacReactiveContext.currentComponent = None;
        return result;
    };

    renderer = __jacResolveRenderer(scope);
    if not renderer {
        console.warn("[Jac] renderJsxTree is not available in client bundle");
    }

    # FIX: Declare reactRoot in the function scope
    let reactRoot = None;

    # 1. Create and store the React 18 root instance
    try {
        reactRoot = ReactDOM.createRoot(rootEl);
        __jacReactiveContext.reactRoot = reactRoot; # Store the root instance
    } except Exception as err {
        console.error("[Jac] Failed to create React root for hydration:", err);
        return;
    }

    # 2. Initial render - call the root component
    value = __jacReactiveContext.rootComponent();

    # 3. Use the stored root for the initial render (hydration)
    if value and __isObject(value) and __isFunction(value.then) {
        value.then(
            lambda node: any -> None {
                reactRoot.render(node);
            }
        ).catch(
            lambda err: any -> None {
                console.error("[Jac] Error resolving client function promise", err);
            }
        );
    } else {
        reactRoot.render(value);
    }
}

def __jacExecuteHydration() -> None {
    registry = __jacEnsureRegistry();
    defaultModule = registry.lastModule if registry.lastModule else "";
    __jacHydrateFromDom(defaultModule);
}

def __jacEnsureHydration(moduleName: str) -> None {
    __jacEnsureObjectGetPolyfill();
    registry = __jacEnsureRegistry();
    registry.lastModule = moduleName;

    existingHydration = registry.__hydration if registry.__hydration else None;
    hydration = existingHydration if existingHydration else {"registered": False};
    registry.__hydration = hydration;

    scope = __jacGlobalScope();
    documentRef = __jacGetDocument(scope);
    if not documentRef {
        return;
    }

    alreadyRegistered = hydration.registered if hydration.registered else False;
    if not alreadyRegistered {
        hydration.registered = True;
        documentRef.addEventListener(
            "DOMContentLoaded",
            lambda _event: any -> None {
                __jacExecuteHydration();
            },
            {"once": True}
        );
    }
}

def __jacRegisterClientModule(
    moduleName: str,
    clientFunctions: list = [],
    clientGlobals: dict = {}
) -> None {
    __jacEnsureObjectGetPolyfill();
    scope = __jacGlobalScope();
    registry = __jacEnsureRegistry();

    moduleFunctions = {};
    registeredFunctions = [];
    if clientFunctions {
        for funcName in clientFunctions {
            funcRef = scope[funcName];
            if not funcRef {
                console.error("[Jac] Client function not found during registration: " + funcName);
                continue;
            }
            moduleFunctions[funcName] = funcRef;
            registry.functions[funcName] = funcRef;
            scope[funcName] = funcRef;
            registeredFunctions.push(funcName);
        }
    }

    moduleGlobals = {};
    globalNames = [];
    globalsMap = clientGlobals if clientGlobals else {};
    for gName in __objectKeys(globalsMap) {
        globalNames.push(gName);
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

    modulesStore = registry.modules if registry.modules else {};
    existingRecord = modulesStore[moduleName] if __jacHasOwn(modulesStore, moduleName) else None;
    moduleRecord = existingRecord if existingRecord else {};
    moduleRecord.moduleFunctions = moduleFunctions;
    moduleRecord.moduleGlobals = moduleGlobals;
    moduleRecord.functions = registeredFunctions;
    moduleRecord.globals = globalNames;
    moduleRecord.defaults = globalsMap;


    # 1. Ensure the module is written to the registry FIRST.
    registry.modules[moduleName] = moduleRecord;

    stateGlobals = registry.state.globals;
    if not __jacHasOwn(stateGlobals, moduleName) {
        stateGlobals[moduleName] = {};
    }

    # 2. ONLY THEN, trigger the hydration/lookup process.
    __jacEnsureHydration(moduleName);
}
}