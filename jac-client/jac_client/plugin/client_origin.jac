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


# ============================================================================
# Reactive State Management System
# ============================================================================

# Global reactive context for managing signals and effects
# Simplified - React Context handles re-rendering for routing
let __jacReactiveContext = {
    "signals": [],              # Global signal storage (enables closures)
    "currentComponent": None,   # Current component ID being rendered
    "currentEffect": None,      # Current effect for dependency tracking
    "mountedComponents": {}     # Track which components have mounted (for onMount)
};


# ============================================================================
# React-Style Routing System (using React Context)
# ============================================================================

# Create React Context for router
let __jacRouterContext = React.createContext(None);

# Router Provider Component - wraps the app and provides routing context
def Router(props: dict) -> any {
    children = props["children"] if "children" in props else [];
    defaultRoute = props["defaultRoute"] if "defaultRoute" in props else "/";
    basename = props["basename"] if "basename" in props else "";

    # Get initial path from hash or use default
    initialPath = __jacGetHashPath();
    if not initialPath {
        initialPath = defaultRoute;
    }
    if basename and initialPath.startsWith(basename) {
        initialPath = initialPath[len(basename):];
    }
    # Normalize path to always start with /
    if initialPath and not initialPath.startsWith("/") {
        initialPath = "/" + initialPath;
    }

    # Use React useState for path - this ensures React handles re-renders
    [pathState, setPathState] = React.useState(initialPath);

    # Create getter function that returns current path
    def currentPath() -> str {
        return pathState;
    }

    # Navigate function
    def navigateTo(path: str) -> None {
        # Normalize path to always start with /
        normalizedPath = path;
        if normalizedPath and not normalizedPath.startsWith("/") {
            normalizedPath = "/" + normalizedPath;
        }
        fullPath = basename + normalizedPath if basename else normalizedPath;
        window.location.hash = "#" + fullPath;
        setPathState(normalizedPath);
    }

    # Listen to hash changes using React useEffect
    React.useEffect(lambda -> None {
        def handleHashChange(event: any) -> None {
            newPath = __jacGetHashPath();
            if basename and newPath.startsWith(basename) {
                newPath = newPath[len(basename):];
            }
            if not newPath {
                newPath = defaultRoute;
            }
            # Normalize path to always start with /
            if newPath and not newPath.startsWith("/") {
                newPath = "/" + newPath;
            }
            setPathState(newPath);
        }

        window.addEventListener("hashchange", handleHashChange);
        window.addEventListener("popstate", handleHashChange);

        # Cleanup function
        return lambda -> None {
            window.removeEventListener("hashchange", handleHashChange);
            window.removeEventListener("popstate", handleHashChange);
        };
    }, []);

    # Router context value - create new object with current path
    routerValue = {
        "location": currentPath,
        "navigate": navigateTo,
        "basename": basename
    };

    # Return Provider component
    return __jacJsx(__jacRouterContext.Provider, {"value": routerValue}, children);
}

# Route Component - renders component when path matches
def Route(props: dict) -> any {
    path = props["path"] if "path" in props else "/";
    # Use bracket notation to avoid 'element' keyword conflict
    elementProp = None;
    if "element" in props {
        elementProp = props["element"];
    }
    component = props["component"] if "component" in props else None;
    guard = props["guard"] if "guard" in props else None;

    # Get router context
    router = React.useContext(__jacRouterContext);
    if not router {
        console.error("[Jac] Route must be used inside Router");
        return None;
    }

    currentPath = router.location();
    isMatch = currentPath == path;

    if not isMatch {
        return None;
    }

    # Check guard if present
    if guard and not guard() {
        return __jacJsx("div", {}, ["Access Denied"]);
    }

    # Render component or element
    if component {
        return component();
    }
    if elementProp {
        return elementProp;
    }

    return None;
}

# Routes Component - renders first matching route
def Routes(props: dict) -> any {
    children = props["children"] if "children" in props else [];

    # Get router context
    router = React.useContext(__jacRouterContext);
    if not router {
        console.error("[Jac] Routes must be used inside Router");
        return __jacJsx("div", {}, ["Router context not found"]);
    }

    currentPath = router.location();

    # Find first matching route
    childrenArray = [];
    if children != None {
        if Array.isArray(children) {
            childrenArray = children;
        } else {
            childrenArray = [children];
        }
    }

    for child in childrenArray {
        # Extract route props from React element
        # Check if child is an object with props (React element)
        if child and child != None and child.props {
            routePath = child.props.path if child.props.path else "/";
            if routePath == currentPath {
                # Check guard if present
                guard = child.props.guard if child.props.guard else None;
                if guard and not guard() {
                    return __jacJsx("div", {}, ["Access Denied"]);
                }
                # Render the matched route
                if child.props.component {
                    return child.props.component();
                } else {
                    # Check for element prop using bracket notation to avoid keyword conflict
                    elementValue = child.props["element"] if child.props["element"] != None else None;
                    if elementValue {
                        return elementValue;
                    }
                }
            }
        }
    }

    # No match - show 404
    return __jacJsx("div", {}, ["404 - Route not found: ", currentPath]);
}

# Link Component - declarative navigation
def Link(props: dict) -> any {
    to = props["to"] if "to" in props else "/";
    href = props["href"] if "href" in props else to;
    # Normalize href to always start with /
    if href and not href.startsWith("/") {
        href = "/" + href;
    }
    children = props["children"] if "children" in props else [];

    # Get router context
    router = React.useContext(__jacRouterContext);

    def handleClick(event: any) -> None {
        event.preventDefault();
        if router {
            router.navigate(href);
        } else {
            # Fallback if no router context
            window.location.hash = "#" + href;
        }
    }

    # Ensure children is properly handled
    childrenArray = [];
    if children != None {
        if Array.isArray(children) {
            childrenArray = children;
        } else {
            childrenArray = [children];
        }
    }

    # Get full href with basename - always ensure it starts with #
    if router and router.basename {
        fullHref = "#" + router.basename + href;
    } else {
        fullHref = "#" + href;
    }

    # Ensure href always starts with # to prevent full page navigation
    if not fullHref.startsWith("#") {
        fullHref = "#" + fullHref;
    }

    # Use onClick (camelCase) for React, and ensure href is hash-based
    return __jacJsx("a", {"href": fullHref, "onClick": handleClick}, childrenArray);
}

# Navigate Component - programmatic redirect
def Navigate(props: dict) -> any {
    to = props["to"] if "to" in props else "/";
    replace = props["replace"] if "replace" in props else False;

    router = React.useContext(__jacRouterContext);
    if router {
        router.navigate(to);
    } else {
        window.location.hash = "#" + to;
    }

    return None;
}

# useNavigate Hook - returns navigate function
def useNavigate() -> any {
    router = React.useContext(__jacRouterContext);
    if not router {
        console.error("[Jac] useNavigate must be used inside Router");
        return lambda path: str -> None {
            window.location.hash = "#" + path;
        };
    }
    return router.navigate;
}

# useLocation Hook - returns current location
def useLocation() -> dict {
    router = React.useContext(__jacRouterContext);
    if not router {
        console.error("[Jac] useLocation must be used inside Router");
        return {"pathname": __jacGetHashPath()};
    }
    return {"pathname": router.location()};
}

# useRouter Hook - returns full router context
def useRouter() -> dict {
    router = React.useContext(__jacRouterContext);
    if not router {
        console.warn("[Jac] useRouter must be used inside Router");
        return None;
    }
    return router;
}

# navigate function - programmatic navigation (backward compatibility)
def navigate(path: str) -> None {
    router = __jacReactiveContext.router;
    if router {
        router.navigate(path);
    } else {
        # Try to get from React context
        # Note: This won't work outside components, but provides fallback
        window.location.hash = "#" + path;
    }
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
    }}

}
