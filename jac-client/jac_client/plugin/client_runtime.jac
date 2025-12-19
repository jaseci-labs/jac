"""Client-side runtime for Jac JSX and walker interactions."""

cl import from 'react' { * as React }
cl import from 'react-dom/client' { * as ReactDOM }
cl import from 'react-router-dom' {
    HashRouter as ReactRouterHashRouter,
    Routes as ReactRouterRoutes,
    Route as ReactRouterRoute,
    Link as ReactRouterLink,
    Navigate as ReactRouterNavigate,
    useNavigate as reactRouterUseNavigate,
    useLocation as reactRouterUseLocation,
    useParams as reactRouterUseParams
}

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
    # React Router Integration (using react-router-dom v6)
    # ============================================================================
    # Direct re-exports of React Router components for seamless integration
    # Router uses HashRouter for hash-based routing (#/path)
    # See: https://reactrouter.com/6.30.1/router-components/hash-router
    glob Router = ReactRouterHashRouter;
    glob Routes = ReactRouterRoutes;
    glob Route = ReactRouterRoute;
    glob Link = ReactRouterLink;
    glob Navigate = ReactRouterNavigate;

    # React Router Hooks - wrapped for Jac compatibility
    glob useNavigate = reactRouterUseNavigate;
    glob useLocation = reactRouterUseLocation;
    glob useParams = reactRouterUseParams;

    # useRouter Hook - convenience hook that combines common router utilities
    def useRouter -> dict {
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

    # navigate function - programmatic navigation (backward compatibility)
    # Note: Use useNavigate() hook inside components instead
    def navigate(path: str) -> None {
        window.location.hash = "#" + path;
    }

    # ============================================================================
    # Walker spawn function
    # ============================================================================
    async def __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
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
            raise Exception(f"Walker {walker} failed: {error_text}") ;
        }

        return await response.json();
    }

    def jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
        return __jacSpawn(left, right, fields);
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
            raise Exception(f"Function {function_name} failed: {error_text}") ;
        }

        data = JSON.parse(await response.text());
        return data["result"];
    }

    # Authentication helpers
    async def jacSignup(email: str, password: str) -> dict {
        response = await fetch(
            "/user/register",
            {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify({"email": email, "password": password})
            }
        );

        if response.ok {
            data = JSON.parse(await response.text());
            token = data["token"];
            if token {
                __setLocalStorage("jac_token", token);
                return {"success": True, "token": token, "email": email};
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

    async def jacLogin(email: str, password: str) -> bool {
        response = await fetch(
            "/user/login",
            {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify({"email": email, "password": password})
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

    def jacLogout -> None {
        __removeLocalStorage("jac_token");
    }

    def jacIsLoggedIn -> bool {
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
}
