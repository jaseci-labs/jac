"""Client-side runtime for Jac JSX and walker interactions."""

# JSX factory function
def __jacJsx(
    tag: any, props: dict = {}, children: list = []
) -> dict;
# DOM rendering function
def renderJsxTree(node: any, container: any) -> None;
# Internal: Build DOM from JSX tree
def __buildDom(node: any) -> any;
# Internal: Apply property to DOM element
def __applyProp(
    element: any, key: str, value: any
) -> None;
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
def createSignal(
    initialValue: any
) -> list;
# Create reactive state (object/dict)
# Returns [getter, setter] tuple for reactive object
def createState(
    initialState: dict
) -> list;
# Run effect when dependencies change
# Executes effectFn and re-runs when tracked signals change
def createEffect(
    effectFn: any
) -> None;
# Run effect once when component mounts (similar to useEffect with empty deps)
# Executes mountFn once when the component first renders
def onMount(
    mountFn: any
) -> None;
# Internal: Track component dependencies
def __jacTrackDependency(
    subscribers: list
) -> None;
# Internal: Notify subscribers of state change
def __jacNotifySubscribers(
    subscribers: list
) -> None;
# Internal: Run an effect function with dependency tracking
def __jacRunEffect(
    effectFn: any
) -> None;
# Schedule a re-render (batched)
def __jacScheduleRerender(componentId: any) -> None;
# Schedule a flush of pending renders
def __jacScheduleFlush -> None;
# Flush all pending renders
def __jacFlushRenders -> None;
# Re-render the root component
def __jacRerenderComponent(componentId: any) -> None;
# ============================================================================
# Declarative Routing System
# ============================================================================

# Route configuration object
obj RouteConfig {
    has path: str,
        component: any,
        guard: any = None;
}
# Create a router instance
def createRouter(
    routes: list, defaultRoute: str = "/"
) -> dict;
# Route config factory
def Route(path: str, component: any, guard: any = None) -> dict;
# Link component for declarative navigation
def Link(props: dict) -> any;
# Navigate programmatically
def navigate(path: str) -> None;
# Hook to access router in components
def useRouter -> dict;
# Internal: Get current hash path
def __jacGetHashPath -> str;
# ============================================================================
# Walker spawn function
# ============================================================================
async def __jacSpawn(
    left: str, right: str = "", fields: dict = {}
) -> any;
# Function call function - calls server-side functions from client
async def __jacCallFunction(
    function_name: str, args: dict = {}
) -> any;
# Authentication helpers
async def jacSignup(username: str, password: str) -> dict;
async def jacLogin(username: str, password: str) -> bool;

def jacLogout -> None;
def jacIsLoggedIn -> bool;
# Browser API shims
def __getLocalStorage(key: str) -> str;
def __setLocalStorage(key: str, value: str) -> None;

def __removeLocalStorage(key: str) -> None;
def __isObject(value: any) -> bool;

def __isFunction(value: any) -> bool;
def __objectKeys(obj: any) -> list;
# Low-level helpers
def __jacHasOwn(obj: any, key: any) -> bool;
# Internal polyfill for Python-style dict.get on plain JS objects
def __jacEnsureObjectGetPolyfill -> None;
# Common utility helpers
def __jacGetDocument(scope: any) -> any;
def __jacParseJsonObject(text: str) -> any;

def __jacBuildOrderedArgs(order: list, argsDict: dict) -> list;
def __jacResolveRenderer(scope: any) -> any;

def __jacResolveTarget(moduleRecord: dict, registry: dict, name: str) -> any;
def __jacSafeCallTarget(
    target: any, scope: any, orderedArgs: list, targetName: str
) -> dict;
# Runtime support helpers for client module registration / hydration
def __jacGlobalScope -> any;
def __jacEnsureRegistry -> dict;
def __jacApplyRender(renderer: any, container: any, node: any) -> None;

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
def useState(
    initialValue: any
) -> list;

def useEffect(effectFn: any, deps: list = []) -> None;
