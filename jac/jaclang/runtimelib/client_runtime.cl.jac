"""Client-side runtime for Jac JSX and walker interactions."""

# JSX element representation
obj JsxElement {
    has tag: any,
        props: dict[str, any] = {},
        children: list[any] = [];
}
# JSX factory function
def __jacJsx(
    tag: any, props: dict[str, any] = {}, children: list[any] = []
) -> JsxElement;
# DOM rendering function
def renderJsxTree(nd: JsxElement, container: any) -> None;
# Internal: Build DOM from JSX tree
def __buildDom(nd: any) -> any;
# Internal: Apply property to DOM element
def __applyProp(element: any, key: str, value: any) -> None;
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
def createSignal(initialValue: any) -> list[any];
# Create reactive state (object/dict)
# Returns [getter, setter] tuple for reactive object
def createState(initialState: dict[str, any]) -> list[any];
# Run effect when dependencies change
# Executes effectFn and re-runs when tracked signals change
def createEffect(effectFn: any) -> None;
# Run effect once when component mounts (similar to useEffect with empty deps)
# Executes mountFn once when the component first renders
def onMount(mountFn: any) -> None;
# Internal: Track component dependencies
def __jacTrackDependency(subscribers: list[any]) -> None;
# Internal: Notify subscribers of state change
def __jacNotifySubscribers(subscribers: list[any]) -> None;
# Internal: Run an effect function with dependency tracking
def __jacRunEffect(effectFn: any) -> None;
# Schedule a re-render (batched)
def __jacScheduleRerender(componentId: any) -> None;
# Schedule a flush of pending renders
def __jacScheduleFlush -> None;
# Flush all pending renders
def __jacFlushRenders -> None;
# Re-render the root component
def __jacRerenderComponent(componentId: any) -> None;
# ============================================================================
# Routing — React Router v6-shaped surface
# ============================================================================
# Bare-serve implements this surface natively (no React dependency); jac-client
# re-exports the same names from `react-router-dom`. User code that uses the
# routing surface is portable between the two runtimes.

# Provider component. In bare-serve this is an identity wrapper — routing
# state lives in `__jacReactiveContext.router`. jac-client aliases this name
# to React Router's `BrowserRouter` so the same JSX (`<Router>...</Router>`)
# works in both runtimes.
def Router(children: any = None) -> JsxElement;

# Picks the matching `<Route>` child against the current URL and renders
# its `element`. Renders `null` if no child matches.
def Routes(children: any = None) -> JsxElement;

# Route configuration. Path may include `:param` placeholders
# (e.g. `/users/:id`) — extracted params are exposed via `useParams`.
# Rendered directly (outside a `<Routes>`) is a no-op.
# `element` is `any` rather than `JsxElement | None` because the JSX prop
# validator currently rejects `JsxElement` against `JsxElement | NoneType`.
def Route(
    path: str = "",
    element: any = None,
    index: bool = False,
    caseSensitive: bool = False,
    children: any = None
) -> JsxElement;

# Declarative navigation link. Renders an `<a>` that intercepts clicks and
# pushes to the History API instead of doing a full page load.
# `to` is a Jac keyword, hence the backtick escape — the public attribute name
# remains `to` for both JSX (`<Link to="/x">`) and call sites.
def Link(
    `to: str,
    replace: bool = False,
    state: any = None,
    className: str = "",
    style: dict[str, str] = {},
    children: any = None
) -> JsxElement;

# Declarative redirect — navigates to `to` on render and renders nothing.
def Navigate(`to: str, replace: bool = False) -> JsxElement;

# Placeholder for nested-route content. Bare-serve's router is currently
# flat (no nested routes), so this is always a no-op; declared for surface
# parity so jac-client apps using `<Outlet/>` typecheck under bare-serve.
def Outlet -> JsxElement;

# Programmatic navigation hook — returns a function that pushes to history.
def useNavigate -> any;

# Current location — `{pathname, search, hash}`. Subscribes to the router
# signal so dependent renders re-run on URL changes.
def useLocation -> dict[str, any];

# URL params from the matched route's `:param` placeholders.
def useParams -> dict[str, any];

# Imperative navigation — equivalent to calling `useNavigate()(path)`.
def navigate(path: str) -> None;

# Returns `{navigate, location, params, pathname, search, hash}` — the
# bundle of router state most apps reach for. Same shape in both runtimes.
def useRouter -> dict[str, any];

# Internal: pathname for the current URL.
def __jacGetPath -> str;

# Internal: lazy-initialize the router state (path signal + popstate listener).
# Declared so the bundler ships the helper alongside the public surface.
def _ensureRouter -> dict[str, any];

# Internal: match a `path` pattern (with `:param` placeholders) against the
# current URL pathname. Returns extracted params on match, `None` on miss.
def _matchRoutePath(pattern: str, path: str) -> any;
# ============================================================================
# Walker spawn function
# ============================================================================
async def __jacSpawn(left: str, right: str = "", fields: dict[str, any] = {}) -> any;
# Synchronous spawn helper — surface parity with jac-client.
def jacSpawn(left: str, right: str = "", fields: dict[str, any] = {}) -> any;
# Function call function - calls server-side functions from client
async def __jacCallFunction(function_name: str, args: dict[str, any] = {}) -> any;
# Authentication helpers
def __normalizeIdentity(x: any) -> dict[str, any];
def __normalizeCredential(x: any) -> dict[str, any];
# `profile` is jac-client-style optional signup metadata; bare-serve forwards
# it to the server unchanged so apps written against jac-client also work
# under bare-serve without per-call edits.
async def jacSignup(
    identities_or_username: (str | list[str]),
    credential_or_password: (str | dict[str, any]),
    profile: (dict[str, any] | None) = None
) -> dict[str, any];

async def jacLogin(
    identity_or_username: (str | dict[str, any]),
    credential_or_password: (str | dict[str, any])
) -> bool;

def jacLogout -> None;
def jacIsLoggedIn -> bool;
# Browser API shims
def __getLocalStorage(key: str) -> str;
def __setLocalStorage(key: str, value: str) -> None;

def __removeLocalStorage(key: str) -> None;
def __isObject(value: any) -> bool;

def __isFunction(value: any) -> bool;
def __objectKeys(`obj: any) -> list[str];
# Low-level helpers
def __jacHasOwn(`obj: any, key: any) -> bool;
# Internal polyfill for Python-style dict.get on plain JS objects
def __jacEnsureObjectGetPolyfill -> None;
# Common utility helpers
def __jacGetDocument(scope: any) -> any;
def __jacParseJsonObject(text: str) -> any;

def __jacBuildOrderedArgs(order: list[str], argsDict: dict[str, any]) -> list[any];
def __jacResolveRenderer(scope: any) -> any;

def __jacResolveTarget(
    moduleRecord: dict[str, any], registry: dict[str, any], name: str
) -> any;

def __jacSafeCallTarget(
    target: any, scope: any, orderedArgs: list[any], targetName: str
) -> dict[str, any];
# Runtime support helpers for client module registration / hydration
def __jacGlobalScope -> any;
def __jacEnsureRegistry -> dict[str, any];
def __jacApplyRender(renderer: any, container: any, nd: any) -> None;

def __jacHydrateFromDom(defaultModuleName: str) -> None;
def __jacExecuteHydration -> None;
def __jacEnsureHydration(moduleName: str) -> None;

def __jacRegisterClientModule(
    moduleName: str, clientFunctions: list[str] = [], clientGlobals: dict[str, any] = {}
) -> None;

# ============================================================================
# React-style API aliases for compatibility
# ============================================================================
# These provide React-like API using the core reactive primitives
def useState(initialValue: any) -> list[any];

def useEffect(effectFn: any, deps: list[any] = []) -> None;

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
def __jacReactErrorHandler(error: any, info: any) -> None;
