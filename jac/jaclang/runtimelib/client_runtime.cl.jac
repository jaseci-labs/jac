"""Client-side runtime for Jac JSX and walker interactions."""

# JSX element representation
obj JsxElement {
    has tag: Any,
        props: dict = {},
        children: list = [];
}
# JSX factory function
def __jacJsx(tag: Any, props: dict = {}, children: list = []) -> JsxElement;
# DOM rendering function
def renderJsxTree(nd: JsxElement, container: Any) -> None;
# Internal: Build DOM from JSX tree
def __buildDom(nd: Any) -> Any;
# Internal: Apply property to DOM element
def __applyProp(element: Any, key: str, value: Any) -> None;
# ============================================================================
# Reactive State Management System
# ============================================================================

# Global reactive context for managing signals, effects, and re-renders
glob __jacReactiveContext = {
         "signals": [],  # Global signal storage (enables closures)
         "pendingRenders": [],  # Batched re-renders queue
         "flushScheduled": False,  # Debounce flag for batching
         "rootComponent": None,  # Root function to re-render
         "currentComponent": None,  # Current component ID being rendered
         "currentEffect": None,  # Current effect for dependency tracking
         "router": None,  # Global router instance
         "mountedComponents": {},  # Track which components have mounted (for onMount)
         "hookIndex": 0,  # Current hook index during render
         "hooks": []
     };
# Create a reactive signal (primitive value)
# Returns [getter, setter] tuple for reactive primitive value
def createSignal(initialValue: Any) -> list;
# Create reactive state (object/dict)
# Returns [getter, setter] tuple for reactive object
def createState(initialState: dict) -> list;
# Run effect when dependencies change
# Executes effectFn and re-runs when tracked signals change
def createEffect(effectFn: Any) -> None;
# Run effect once when component mounts (similar to useEffect with empty deps)
# Executes mountFn once when the component first renders
def onMount(mountFn: Any) -> None;
# Internal: Track component dependencies
def __jacTrackDependency(subscribers: list) -> None;
# Internal: Notify subscribers of state change
def __jacNotifySubscribers(subscribers: list) -> None;
# Internal: Run an effect function with dependency tracking
def __jacRunEffect(effectFn: Any) -> None;
# Schedule a re-render (batched)
def __jacScheduleRerender(componentId: Any) -> None;
# Schedule a flush of pending renders
def __jacScheduleFlush -> None;
# Flush all pending renders
def __jacFlushRenders -> None;
# Re-render the root component
def __jacRerenderComponent(componentId: Any) -> None;
# ============================================================================
# Declarative Routing System
# ============================================================================

# Route configuration object
obj RouteConfig {
    has path: str,
        component: Any,
        guard: Any = None;
}
# Create a router instance
def createRouter(routes: list, defaultRoute: str = "/") -> dict;
# Route config factory
def Route(path: str, component: Any, guard: Any = None) -> dict;
# Link component for declarative navigation
def Link(props: dict) -> JsxElement;
# Navigate programmatically
def navigate(path: str) -> None;
# Hook to access router in components
def useRouter -> dict;
# Internal: Get current path from browser URL
def __jacGetPath -> str;
# ============================================================================
# Walker spawn function
# ============================================================================
async def __jacSpawn(left: str, right: str = "", fields: dict = {}) -> Any;
# Function call function - calls server-side functions from client
async def __jacCallFunction(function_name: str, args: dict = {}) -> Any;
# Authentication helpers
def __normalizeIdentity(x: Any) -> dict;
def __normalizeCredential(x: Any) -> dict;
async def jacSignup(
    identities_or_username: (str | list), credential_or_password: (str | dict)
) -> dict;

async def jacLogin(
    identity_or_username: (str | dict), credential_or_password: (str | dict)
) -> bool;

def jacLogout -> None;
def jacIsLoggedIn -> bool;
# Browser API shims
def __getLocalStorage(key: str) -> str;
def __setLocalStorage(key: str, value: str) -> None;

def __removeLocalStorage(key: str) -> None;
def __isObject(value: Any) -> bool;

def __isFunction(value: Any) -> bool;
def __objectKeys(`obj: Any) -> list;
# Low-level helpers
def __jacHasOwn(`obj: Any, key: Any) -> bool;
# Internal polyfill for Python-style dict.get on plain JS objects
def __jacEnsureObjectGetPolyfill -> None;
# Common utility helpers
def __jacGetDocument(scope: Any) -> Any;
def __jacParseJsonObject(text: str) -> Any;

def __jacBuildOrderedArgs(order: list, argsDict: dict) -> list;
def __jacResolveRenderer(scope: Any) -> Any;

def __jacResolveTarget(moduleRecord: dict, registry: dict, name: str) -> Any;
def __jacSafeCallTarget(
    target: Any, scope: Any, orderedArgs: list, targetName: str
) -> dict;
# Runtime support helpers for client module registration / hydration
def __jacGlobalScope -> Any;
def __jacEnsureRegistry -> dict;
def __jacApplyRender(renderer: Any, container: Any, nd: Any) -> None;

def __jacHydrateFromDom(defaultModuleName: str) -> None;
def __jacExecuteHydration -> None;
def __jacEnsureHydration(moduleName: str) -> None;

def __jacRegisterClientModule(
    moduleName: str, clientFunctions: list = [], clientGlobals: dict = {}
) -> None;

# ============================================================================
# React-style API aliases for compatibility
# ============================================================================
# These provide React-like API using the core reactive primitives
def useState(initialValue: Any) -> list;

def useEffect(effectFn: Any, deps: list = []) -> None;

# ============================================================================
# Client Error Reporting
# ============================================================================
# Report client-side errors to the server for logging.
# `componentStack` carries React's named call chain (e.g. "in App\n  in Router")
# captured by the boundary's onError; the JS `stack` is engine frames only.
def __jacReportError(
    message: str,
    stack: str = "",
    url: str = "",
    source: str = "",
    componentStack: str = ""
) -> None;
# Install global error handlers (window.onerror, unhandledrejection)
def __jacInstallErrorHandlers -> None;
# onError prop for ErrorBoundary; captures React's componentStack which
# FallbackComponent props don't expose, then forwards via __jacReportError.
def __jacReactErrorHandler(error: Any, info: Any) -> None;
