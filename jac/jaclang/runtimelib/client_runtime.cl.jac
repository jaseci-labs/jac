"""Client-side runtime for Jac JSX and walker interactions."""

def __jacJsx(tag: any, props: dict = {}, children: list = []) -> dict;

def renderJsxTree(node: any, container: any) -> None;

def __buildDom(node: any) -> any;
# Internal: Apply property to DOM element
def __applyProp(
    element: any, key: str, value: any
) -> None;

glob __jacReactiveContext = {
         "signals": [],  # Global signal storage (enables closures)
         "pendingRenders": [],  # Batched re-renders queue
         "flushScheduled": False,  # Debounce flag for batching
         "rootComponent": None,  # Root function to re-render
         "currentComponent": None,  # Current component ID being rendered
         "currentEffect": None,  # Current effect for dependency tracking
         "router": None,  # Global router instance
         "mountedComponents": {}  # Track which components have mounted (for onMount)
     };
# Create a reactive signal (primitive value)
# Returns [getter, setter] tuple for reactive primitive value
def createSignal(
# Create reactive state (object/dict)
# Returns [getter, setter] tuple for reactive object

# Run effect when dependencies change
# Executes effectFn and re-runs when tracked signals change

# Run effect once when component mounts (similar to useEffect with empty deps)
# Executes mountFn once when the component first renders

# Internal: Track component dependencies

# Internal: Notify subscribers of state change

# Internal: Run an effect function with dependency tracking

# Schedule a re-render (batched)

    initialValue: any
) -> list;

def createState(
# Schedule a flush of pending renders

# Flush all pending renders

# Re-render the root component

# ============================================================================
# Declarative Routing System
# ============================================================================

# Route configuration object

    initialState: dict
) -> list;

def createEffect(
# Create a router instance

# Route config factory

# Link component for declarative navigation

# Navigate programmatically

# Hook to access router in components

# Internal: Get current hash path

# ============================================================================
# Walker spawn function
# ============================================================================

# Function call function - calls server-side functions from client

    effectFn: any
) -> None;

def onMount(
# Authentication helpers

    mountFn: any
) -> None;

def __jacTrackDependency(
# Browser API shims

# Low-level helpers

# Internal polyfill for Python-style dict.get on plain JS objects

# Common utility helpers

    subscribers: list
) -> None;

def __jacNotifySubscribers(
# Runtime support helpers for client module registration / hydration

    subscribers: list
) -> None;

def __jacRunEffect(effectFn: any) -> None;

def __jacScheduleRerender(componentId: any) -> None;

def __jacScheduleFlush -> None;

def __jacFlushRenders -> None;

def __jacRerenderComponent(componentId: any) -> None;

obj RouteConfig {
    has path: str,
        component: any,
        guard: any = None;
}

def createRouter(routes: list, defaultRoute: str = "/") -> dict;

def Route(path: str, component: any, guard: any = None) -> dict;

def Link(props: dict) -> any;

def navigate(path: str) -> None;

def useRouter -> dict;

def __jacGetHashPath -> str;

async def __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;

async def __jacCallFunction(function_name: str, args: dict = {}) -> any;

async def jacSignup(username: str, password: str) -> dict;
async def jacLogin(username: str, password: str) -> bool;

def jacLogout -> None;
def jacIsLoggedIn -> bool;

def __getLocalStorage(key: str) -> str;
def __setLocalStorage(key: str, value: str) -> None;

def __removeLocalStorage(key: str) -> None;
def __isObject(value: any) -> bool;

def __isFunction(value: any) -> bool;
def __objectKeys(obj: any) -> list;

def __jacHasOwn(obj: any, key: any) -> bool;

def __jacEnsureObjectGetPolyfill -> None;

def __jacGetDocument(scope: any) -> any;
def __jacParseJsonObject(text: str) -> any;

def __jacBuildOrderedArgs(order: list, argsDict: dict) -> list;
def __jacResolveRenderer(scope: any) -> any;

def __jacResolveTarget(moduleRecord: dict, registry: dict, name: str) -> any;
def __jacSafeCallTarget(
    target: any, scope: any, orderedArgs: list, targetName: str
) -> dict;

def __jacGlobalScope -> any;
def __jacEnsureRegistry -> dict;
def __jacApplyRender(renderer: any, container: any, node: any) -> None;

def __jacHydrateFromDom(defaultModuleName: str) -> None;
def __jacExecuteHydration -> None;
def __jacEnsureHydration(moduleName: str) -> None;

def __jacRegisterClientModule(
    moduleName: str, clientFunctions: list = [], clientGlobals: dict = {}
) -> None;
# JSX factory function

# DOM rendering function

# Internal: Build DOM from JSX tree

# ============================================================================
# Reactive State Management System
# ============================================================================

# Global reactive context for managing signals, effects, and re-renders
