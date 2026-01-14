impl __jacJsx(tag: any, props: dict = {}, children: any = []) -> any {
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
    window.location.hash = "#" + path;
}

impl __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
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
        raise Exception(f"Walker {walker_name} failed: {error_text}") ;
    }
    payload = await response.json();
    return payload["data"] if payload["data"] else {};
}

impl jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
    return __jacSpawn(left, right, fields);
}

impl __jacCallFunction(function_name: str, args: dict = {}) -> any {
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
    payload = await response.json();
    if not payload["ok"] {
        error_msg = payload["error"] if payload["error"] else "Unknown error";
        raise Exception(f"Function {function_name} failed: {error_msg}") ;
    }
    result = None;
    try {
        if payload["data"] and payload["data"]["result"] {
            result = payload["data"]["result"];
        }
    } except Exception { }
    return result;
}

impl jacSignup(username: str, password: str) -> dict {
    response = await fetch(
        "/user/register",
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
        console.log("data", data);
        token = None;
        try {
            if data["data"] and data["data"]["token"] {
                token = data["data"]["token"];
            }
        } except Exception { }
        console.log("token", token);
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
