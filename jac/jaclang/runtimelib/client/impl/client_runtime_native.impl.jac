impl __jacWirePlatformAdapters -> None {
    globalThis.__jacGetRenderer__ = __jacGetRenderer;
    globalThis.__jacGetApiBaseUrl__ = __getApiBaseUrl;

    globalThis.__jacPlatformReady__ = __ensureNativeTokenPrimed();
    globalThis.__jacGetLocalStorage__ = __getLocalStorage;
    globalThis.__jacSetLocalStorage__ = __setLocalStorage;
    globalThis.__jacRemoveLocalStorage__ = __removeLocalStorage;
    globalThis.__jacSeedEndpointEffects__ = lambda -> dict {
        seed = globalThis.__JAC_INIT__;
        if seed and seed.endpointEffects {
            return seed.endpointEffects;
        }
        return {};
    };
    globalThis.__jacHandleWalkerUnauthorized__ = lambda {
        console.warn(
            "[jac-native-runtime] Walker returned 401; cleared token. "
            "Redirecting to login."
        );
        navigate("/login");
    };
    globalThis.__jacDefaultErrorReportUrl__ = lambda -> str { return ""; };
}

impl __jacGetRenderer -> any {
    if not globalThis.__jacRenderer__ {
        globalThis.__jacRenderer__ = {"create": __jacNativeCreate};
    }
    return globalThis.__jacRenderer__;
}

impl __jacNativeCreate(tag: any, props: dict = {}, children: any = []) -> JsxElement {
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
    flat = [];
    for child in childrenArray {
        if child == None or child == undefined {
            continue;
        }
        flat.append(child);
    }
    if typeof(tag) != "string" {
        args = [tag, props];
        for child in flat {
            args.append(child);
        }
        return React.createElement.apply(React, args);
    }
    adapted = _adaptProps(tag, props);
    if _VIEW_TAGS.includes(tag) {
        args = [RNView, adapted];
        for child in flat {
            args.append(child);
        }
        return React.createElement.apply(React, args);
    }
    if _TEXT_TAGS.includes(tag) {
        args = [RNText, adapted];
        for child in flat {
            args.append(child);
        }
        return React.createElement.apply(React, args);
    }
    if tag == "button" {
        text_props = {"style": _textStyleFrom(adapted["style"])};
        textChild = React.createElement.apply(
            React, _prepend_args(RNText, text_props, flat)
        );
        return React.createElement(RNPressable, adapted, textChild);
    }
    if tag == "input" or tag == "textarea" {
        if tag == "textarea" {
            adapted["multiline"] = True;
        }
        return React.createElement(RNTextInput, adapted);
    }
    if tag == "img" {
        return React.createElement(RNImage, _adaptImageProps(adapted));
    }
    if tag == "a" {
        return _makeNativeLink(adapted, flat);
    }
    if not _UNMAPPED_WARNED[tag] {
        _UNMAPPED_WARNED[tag] = True;
        console.warn(
            f"[jac-native-runtime] Unmapped HTML tag <{tag}>. Rendering as "
            "<View> with a debug border."
        );
    }
    debug_adapted = adapted;
    if globalThis.__DEV__ {
        existing_style = adapted["style"] if adapted["style"] else None;
        unmapped_style = {
            "borderWidth": 1,
            "borderColor": "red",
            "borderStyle": "dashed"
        };
        debug_adapted = Object.assign({}, adapted);
        debug_adapted["style"] = [unmapped_style, existing_style]
            if existing_style
            else unmapped_style;
    }
    args = [RNView, debug_adapted];
    for child in flat {
        args.append(child);
    }
    return React.createElement.apply(React, args);
}

impl _adaptProps(tag: str, props: dict) -> dict {
    if not props {
        return {};
    }
    out = {};
    keys = Object.keys(props);
    for key in keys {
        value = props[key];
        if value == None or value == undefined {
            continue;
        }
        if key == "class" or key == "className" {
            out["accessibilityLabel"] = str(value);
        } elif key == "style" {
            out["style"] = value;
        } elif key == "onClick" {
            out["onPress"] = value;
        } elif key == "onChange" {
            user_on_change = value;
            out["onChangeText"] = lambda text: any { user_on_change(
                {"target": {"value": text}}
            ); };
        } elif key == "value"
        or key == "placeholder"
        or key == "editable"
        or key == "multiline"
        or key == "secureTextEntry"
        or key == "key"
        or key == "ref" {
            out[key] = value;
        } elif key.startsWith("data-") or key.startsWith("aria-") {
            continue;
        } else {
            out[key] = value;
        }
    }
    return out;
}

impl _textStyleFrom(style: any) -> dict {
    out = {};
    if style == None or style == undefined {
        return out;
    }
    text_keys = [
        "color",
        "fontSize",
        "fontWeight",
        "fontFamily",
        "fontStyle",
        "lineHeight",
        "letterSpacing",
        "textAlign",
        "textDecorationLine",
        "textTransform"
    ];
    sources = style if Array.isArray(style) else [style];
    for src in sources {
        if src == None or src == undefined {
            continue;
        }
        for key in text_keys {
            value = src[key];
            if value != None and value != undefined {
                out[key] = value;
            }
        }
    }
    return out;
}

impl _isAbsoluteImageUri(src: str) -> bool {
    lower = src.lower();
    return (
        lower.startswith("http://")
        or lower.startswith("https://")
        or lower.startswith("data:")
        or lower.startswith("file://")
        or lower.startswith("content://")
        or lower.startswith("asset:/")
    );
}

impl _adaptImageProps(props: dict) -> dict {
    out = Object.assign({}, props or {});
    src = out["src"] if out["src"] else None;
    if out["alt"] and not out["accessibilityLabel"] {
        out["accessibilityLabel"] = str(out["alt"]);
    }
    if src != None and out["source"] == None {
        if typeof(src) == "number" {
            out["source"] = src;
        } else {
            uri = str(src);
            asset_map = globalThis.__JAC_RN_ASSET_MAP__ or {};
            mapped_asset = asset_map[uri] if asset_map else None;
            if mapped_asset != None {
                out["source"] = mapped_asset;
            } elif uri.startswith("__jac_rn_asset__:") {
                if not _RELATIVE_IMG_SRC_WARNED[uri] {
                    _RELATIVE_IMG_SRC_WARNED[uri] = True;
                    console.warn(
                        "[jac-native-runtime] Missing Metro asset mapping for token " + str(
                            uri
                        ) + ". Re-run jac build --client react-native."
                    );
                }
                out["source"] = {"uri": uri};
            } elif uri.startswith("/") and not _isAbsoluteImageUri(uri) {
                base = __getApiBaseUrl();
                if base {
                    uri = str(base).rstrip("/") + uri;
                }
                out["source"] = {"uri": uri};
            } elif not _isAbsoluteImageUri(uri) {
                if not _RELATIVE_IMG_SRC_WARNED[uri] {
                    _RELATIVE_IMG_SRC_WARNED[uri] = True;
                    console.warn(
                        "[jac-native-runtime] Relative <img src> path " + str(uri) + " cannot be bundled reliably on React Native. " + "Use imported assets, /static/... URLs, absolute URLs, " + "or pass source={{uri: ...}}."
                    );
                }
                out["source"] = {"uri": uri};
            } else {
                out["source"] = {"uri": uri};
            }
        }
    }
    if out["src"] != None {
        Reflect.deleteProperty(out, "src");
    }
    if out["alt"] != None {
        Reflect.deleteProperty(out, "alt");
    }
    return out;
}

impl _prepend_args(comp: any, props: any, children: list) -> list {
    args = [comp, props];
    for child in children {
        args.append(child);
    }
    return args;
}

impl _makeNativeLink(props: dict, children: list) -> JsxElement {
    href = props["href"] if props["href"] else None;
    rest = Object.assign({}, props);
    if rest["href"] {
        Reflect.deleteProperty(rest, "href");
    }
    if href {
        rest["onPress"] = lambda { if href.startswith("http://")
        or href.startswith("https://")
        or href.startswith("mailto:")
        or href.startswith("tel:") {
            RNLinking.openURL(href).catch(
                lambda e: any { console.warn("RNLinking.openURL failed", e); }
            );
        } else {
            navigate(href);
        } };
    }
    args = [RNText, rest];
    for child in children {
        args.append(child);
    }
    return React.createElement.apply(React, args);
}

impl _toChildrenArray(children: any) -> list {
    if children == None or children == undefined {
        return [];
    }
    if Array.isArray(children) {
        return children;
    }
    return [children];
}

impl _normalizeRoutePath(path: str) -> str {
    text = str(path or "").strip();
    if text == "" {
        return "/";
    }
    if not text.startswith("/") {
        text = "/" + text;
    }
    if len(text) > 1 and text.endswith("/") {
        text = text.rstrip("/");
    }
    return text;
}

impl _joinRoutePath(parent_path: str, child_path: str) -> str {
    child = str(child_path or "");
    if child == "" {
        return _normalizeRoutePath(parent_path);
    }
    if child.startswith("/") {
        return _normalizeRoutePath(child);
    }
    base = _normalizeRoutePath(parent_path);
    if base == "/" {
        return _normalizeRoutePath("/" + child);
    }
    return _normalizeRoutePath(base + "/" + child);
}

impl _splitRouteParts(path: str) -> list[str] {
    text = _normalizeRoutePath(path);
    if text == "/" {
        return [];
    }
    parts = [];
    for part in text.split("/") {
        if part != "" {
            parts.append(part);
        }
    }
    return parts;
}

impl _buildRouteName(path: str) -> str {
    normalized = _normalizeRoutePath(path);
    if normalized == "/" {
        return "root";
    }

    return normalized[1:].replace(":", "$");
}

impl _cacheNativeRoutes(route_defs: list) {
    slim = [];
    for route in route_defs {
        slim.append({"name": route["name"], "path": route["path"]});
    }
    globalThis.__jacNativeRouteDefs__ = slim;
}

impl _getNativeRoutes -> list {
    routes = globalThis.__jacNativeRouteDefs__;
    if routes and Array.isArray(routes) {
        return routes;
    }
    return [];
}

impl _matchRoutePattern(pattern_path: str, actual_path: str) -> (dict | None) {
    pattern_parts = _splitRouteParts(pattern_path);
    actual_parts = _splitRouteParts(actual_path);
    if len(pattern_parts) != len(actual_parts) {
        return None;
    }
    params = {};
    for idx in range(len(pattern_parts)) {
        pattern_part = pattern_parts[idx];
        actual_part = actual_parts[idx];
        if pattern_part.startswith(":") {
            key = pattern_part[1:];
            params[key] = decodeURIComponent(actual_part);
        } elif pattern_part != actual_part {
            return None;
        }
    }
    return params;
}

impl _lookupRouteByPath(path: str) -> (dict | None) {
    normalized = _normalizeRoutePath(path);
    for route in _getNativeRoutes() {
        if route["path"] == normalized {
            return {"name": route["name"], "path": route["path"], "params": {}};
        }
    }
    for route in _getNativeRoutes() {
        params = _matchRoutePattern(route["path"], normalized);
        if params is not None {
            return {"name": route["name"], "path": route["path"], "params": params};
        }
    }
    return None;
}

impl _lookupRouteByName(name: str) -> (dict | None) {
    for route in _getNativeRoutes() {
        if route["name"] == name {
            return route;
        }
    }
    return None;
}

impl _hydratePath(pattern_path: str, params: any) -> str {
    parts = _splitRouteParts(pattern_path);
    hydrated = [];
    for part in parts {
        if part.startswith(":") {
            key = part[1:];
            value = params[key] if params and params[key] != None else "";
            hydrated.append(encodeURIComponent(str(value)));
        } else {
            hydrated.append(part);
        }
    }
    return _normalizeRoutePath("/" + "/".join(hydrated));
}

impl _stripMetaParams(params: any) -> dict {
    result = {};
    if not params {
        return result;
    }
    for key in Object.keys(params) {
        if key.startswith("__jac") {
            continue;
        }
        result[key] = params[key];
    }
    return result;
}

impl _performNavigation(nav: any, target: any, options: dict = {}) -> None {
    if nav == None {
        console.warn("[jac-native-runtime] navigation is unavailable.");
        return;
    }
    if typeof(target) == "number" {
        if target < 0 and nav.goBack {
            nav.goBack();
        }
        return;
    }
    to = str(target or "/");
    if to.startswith("http://") or to.startswith("https://") {
        RNLinking.openURL(to).catch(
            lambda e: any { console.warn("RNLinking.openURL failed", e); }
        );
        return;
    }
    normalized = to;
    query = "";
    fragment = "";
    hash_idx = normalized.indexOf("#");
    if hash_idx >= 0 {
        fragment = normalized[hash_idx + 1:];
        normalized = normalized[:hash_idx];
    }
    q_idx = normalized.indexOf("?");
    if q_idx >= 0 {
        query = normalized[q_idx + 1:];
        normalized = normalized[:q_idx];
    }
    route_match = _lookupRouteByPath(normalized);
    if route_match is None {
        console.warn(
            f"[jac-native-runtime] No native route matched '{normalized}'. "
            "Define it with <Route path=...>."
        );
        return;
    }
    params = Object.assign({}, route_match["params"] or {});
    if query != "" {
        params["__jacSearch"] = "?" + query;
    }
    if fragment != "" {
        params["__jacHash"] = "#" + fragment;
    }
    if options and options["state"] != None {
        params["__jacState"] = options["state"];
    }
    if options and options["replace"] {
        nav.dispatch(
            JacCommonActions.reset(
                {
                    "index": 0,
                    "routes": [{"name": route_match["name"], "params": params}]
                }
            )
        );
        return;
    }
    nav.navigate(route_match["name"], params);
}

impl _collectNativeRoutes(
    children: any, parent_path: str, wrappers: list, out_routes: list
) {
    for child in _toChildrenArray(children) {
        if not React.isValidElement(child) {
            continue;
        }
        if child.type != __nativeRoute {
            continue;
        }
        props = child.props or {};
        route_path = str(props.path) if props.path else "";
        route_element = props.element;
        full_path = _joinRoutePath(parent_path, route_path);
        if route_path != "" and route_element != None {
            out_routes.append(
                {
                    "name": _buildRouteName(full_path),
                    "path": full_path,
                    "element": route_element,
                    "wrappers": wrappers
                }
            );
        }
        next_wrappers = wrappers;
        if route_element != None and props.children {
            next_wrappers = wrappers + [route_element];
        } elif route_element != None and route_path == "" {
            next_wrappers = wrappers + [route_element];
        }
        next_parent = full_path if route_path != "" else parent_path;
        if props.children {
            _collectNativeRoutes(
                props.children, next_parent, next_wrappers, out_routes
            );
        }
    }
}

impl _makeNativeRouteScreen(route: dict) -> any {
    wrappers = route["wrappers"] if route["wrappers"] else [];
    element = route["element"]
        if route["element"]
        else React.createElement(RNView, None);
    return lambda -> JsxElement {
        content = element;
        idx = len(wrappers) - 1;
        while idx >= 0 {
            wrapper = wrappers[idx];
            content = React.createElement(
                _JAC_NATIVE_OUTLET_CONTEXT.Provider, {"value": content}, wrapper
            );
            idx -= 1;
        }
        return content;
    };
}

impl __nativeRouter(props: dict = {}) -> JsxElement {
    nav_ref = React.useRef(None);
    React.useEffect(lambda { globalThis.__jacNativeNavigationRef__ = nav_ref; }, []);
    def _flushPendingNavigation {
        pending = globalThis.__jacPendingNavigation__;
        if pending {
            globalThis.__jacPendingNavigation__ = None;

            _performNavigation(nav_ref.current, pending, {"replace": True});
        }
    }
    return React.createElement(
        JacNavigationContainer,
        {"ref": nav_ref, "onReady": _flushPendingNavigation},
        props.children
    );
}

impl __nativeRoutes(props: dict = {}) -> JsxElement {
    routes = React.useMemo(
        lambda -> list {
            out = [];
            _collectNativeRoutes(props.children, "/", [], out);
            return out;
        },
        []
    );
    React.useEffect(lambda { _cacheNativeRoutes(routes); }, [routes]);

    screens = React.useMemo(
        lambda -> list {
            out = [];
            for route in routes {
                out.append(
                    React.createElement(
                        _JAC_NATIVE_STACK.Screen,
                        {
                            "key": route["name"],
                            "name": route["name"],
                            "component": _makeNativeRouteScreen(route)
                        }
                    )
                );
            }
            return out;
        },
        [routes]
    );
    if len(routes) == 0 {
        return React.createElement(
            RNView,
            {"style": {"padding": 16}},
            React.createElement(
                RNText,
                {"style": {"color": "#dc2626"}},
                "No native routes found. Add <Route path=... element=.../>."
            )
        );
    }
    args = [_JAC_NATIVE_STACK.Navigator, {"initialRouteName": routes[0]["name"]}];
    for screen in screens {
        args.append(screen);
    }
    return React.createElement.apply(React, args);
}

impl __nativeRoute(props: dict = {}) -> JsxElement {
    return None;
}

impl __nativeLink(props: dict = {}) -> JsxElement {
    to = props.to or (props.href or "/");
    rest = Object.assign({}, props);
    if rest["to"] {
        Reflect.deleteProperty(rest, "to");
    }
    if rest["href"] {
        Reflect.deleteProperty(rest, "href");
    }
    if rest["replace"] {
        Reflect.deleteProperty(rest, "replace");
    }
    user_press = rest["onPress"] if rest["onPress"] else None;
    nav_fn = useNavigate();
    rest["onPress"] = lambda {
        if user_press {
            user_press();
        }
        nav_fn(to, {"replace": props.replace == True});
    };
    children = _toChildrenArray(props.children or to);

    label = React.createElement.apply(
        React, _prepend_args(RNText, {"style": _textStyleFrom(rest["style"])}, children)
    );
    return React.createElement(RNPressable, rest, label);
}

impl __nativeNavigate(props: dict = {}) -> JsxElement {
    target = props.to if props and props.to else "/";
    should_replace = props.replace == True if props else False;
    nav_fn = useNavigate();
    reactUseEffect(
        lambda { nav_fn(target, {"replace": should_replace, "state": props.state}); },
        [target, should_replace]
    );
    return None;
}

impl __nativeOutlet(props: dict = {}) -> JsxElement {
    return React.useContext(_JAC_NATIVE_OUTLET_CONTEXT);
}

impl useRouter -> dict {
    nav_fn = useNavigate();
    location = useLocation();
    params = useParams();
    return {
        "navigate": nav_fn,
        "location": location,
        "params": params,
        "pathname": location.pathname,
        "search": location.search,
        "hash": location.hash
    };
}

impl useNavigate -> any {
    nav = jacUseNavigation();
    def _navigate(target: any, options: (dict | None) = None) {
        _performNavigation(nav, target, options or {});
    }
    return _navigate;
}

impl useLocation -> dict {
    route = jacUseRoute();
    pathname = "/";
    search = "";
    hash = "";
    state = None;
    params = route.params if route and route.params else {};
    route_name = route.name if route and route.name else "";
    route_def = _lookupRouteByName(route_name);
    if route_def {
        pathname = _hydratePath(route_def["path"], params);
    }
    if params and params["__jacSearch"] {
        search = str(params["__jacSearch"]);
    }
    if params and params["__jacHash"] {
        hash = str(params["__jacHash"]);
    }
    if params and params["__jacState"] != None {
        state = params["__jacState"];
    }
    return {"pathname": pathname, "search": search, "hash": hash, "state": state};
}

impl useParams -> dict {
    route = jacUseRoute();
    params = route.params if route and route.params else {};
    return _stripMetaParams(params);
}

impl navigate(path: str) -> None {
    nav_ref = globalThis.__jacNativeNavigationRef__;
    nav = nav_ref.current if nav_ref and nav_ref.current else None;
    if nav == None {
        globalThis.__jacPendingNavigation__ = path;
        return;
    }
    _performNavigation(nav, path, {});
}

impl __getApiBaseUrl -> str {
    build_time = globalThis.__JAC_API_BASE_URL__;
    if build_time {
        return build_time;
    }
    try {
        cfg = ExpoConstants.expoConfig;
        if cfg and cfg.extra and cfg.extra.apiBaseUrl {
            return cfg.extra.apiBaseUrl;
        }
    } except Exception { }
    if not globalThis.__jacWarnedMissingApiBaseUrl__ {
        globalThis.__jacWarnedMissingApiBaseUrl__ = True;
        console.warn(
            "[jac-native-runtime] Missing API base URL. Set expo.extra.apiBaseUrl "
            "or run jac start --client react-native --dev so it is injected."
        );
    }
    return "";
}

def _nativeStorageCache -> dict {
    if not globalThis.__jacNativeStorageCache__ {
        globalThis.__jacNativeStorageCache__ = {};
    }
    return globalThis.__jacNativeStorageCache__;
}

impl __getLocalStorage(key: str) -> str {
    cache = _nativeStorageCache();
    if key in cache {
        return cache[key];
    }
    SecureStore.getItemAsync(key).then(
        lambda val: any { cache[key] = val or ""; }
    ).catch(
        lambda e: any { console.warn("SecureStore.getItemAsync failed", e); }
    );
    return "";
}

impl __setLocalStorage(key: str, value: str) -> None {
    _nativeStorageCache()[key] = value;
    SecureStore.setItemAsync(key, value).catch(
        lambda e: any { console.warn("SecureStore.setItemAsync failed", e); }
    );
}

impl __removeLocalStorage(key: str) -> None {
    Reflect.deleteProperty(_nativeStorageCache(), key);
    SecureStore.deleteItemAsync(key).catch(
        lambda e: any { console.warn("SecureStore.deleteItemAsync failed", e); }
    );
}

impl __getLocalStorageAsync(key: str) -> str {
    val = await SecureStore.getItemAsync(key);
    _nativeStorageCache()[key] = val or "";
    return val or "";
}

impl __setLocalStorageAsync(key: str, value: str) -> None {
    _nativeStorageCache()[key] = value;
    await SecureStore.setItemAsync(key, value);
}

impl __removeLocalStorageAsync(key: str) -> None {
    Reflect.deleteProperty(_nativeStorageCache(), key);
    await SecureStore.deleteItemAsync(key);
}

impl __primeNativeTokenCache -> None {
    cache = _nativeStorageCache();
    try {
        token = await SecureStore.getItemAsync("jac_token");
        cache["jac_token"] = token or "";
    } except Exception as e {
        console.warn("[jac-native-runtime] __primeNativeTokenCache failed", e);
    }

    globalThis.__jacNativeTokenPrimed__ = True;
}

impl __ensureNativeTokenPrimed -> any {
    if not globalThis.__jacNativeTokenPrimePromise__ {
        globalThis.__jacNativeTokenPrimePromise__ = __primeNativeTokenCache();
    }
    return globalThis.__jacNativeTokenPrimePromise__;
}

impl AuthGuard(redirect: str = "/login") -> JsxElement {
    [ready, setReady] = useState(globalThis.__jacNativeTokenPrimed__ == True);
    React.useEffect(
        lambda {
            if ready {
                return None;
            }
            mounted = {"v": True};
            __ensureNativeTokenPrimed().then(
                lambda _: any { if mounted["v"] { setReady(True); }}
            );
            return lambda { mounted["v"] = False; };
        },
        []
    );
    if not ready {
        return None;
    }
    if jacIsLoggedIn() {
        return React.createElement(__nativeOutlet, None);
    }
    return React.createElement(__nativeNavigate, {"to": redirect, "replace": True});
}

impl ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement {
    err_obj = error.error if error and error.error else error;
    msg = err_obj.message if err_obj and err_obj.message else str(err_obj);
    reset_fn = error.resetErrorBoundary
        if error and error.resetErrorBoundary
        else resetErrorBoundary;
    return React.createElement(
        RNView,
        {"style": {"padding": 24, "flex": 1, "justifyContent": "center"}},
        React.createElement(
            RNText,
            {
                "style": {
                    "fontWeight": "bold",
                    "color": "#dc2626",
                    "fontSize": 18,
                    "marginBottom": 12
                }
            },
            "Something went wrong"
        ),
        React.createElement(
            RNText, {"style": {"color": "#374151", "marginBottom": 16}}, msg
        ),
        React.createElement(
            RNPressable,
            {
                "onPress": reset_fn,
                "style": {
                    "backgroundColor": "#2563eb",
                    "padding": 12,
                    "borderRadius": 8,
                    "alignSelf": "flex-start"
                }
            },
            React.createElement(
                RNText, {"style": {"color": "white", "fontWeight": "600"}}, "Try again"
            )
        )
    );
}

impl errorOverlay(filePath: str, errors: str) -> JsxElement {
    return React.createElement(
        RNView,
        {"style": {"padding": 24, "flex": 1, "backgroundColor": "#1e1e1e"}},
        React.createElement(
            RNText,
            {
                "style": {
                    "color": "#ff6b6b",
                    "fontWeight": "bold",
                    "fontSize": 16,
                    "marginBottom": 12
                }
            },
            "Compilation Error"
        ),
        React.createElement(
            RNText, {"style": {"color": "#64b5f6", "marginBottom": 8}}, filePath
        ),
        React.createElement(
            RNText, {"style": {"color": "#ff6b6b", "fontFamily": "monospace"}}, errors
        )
    );
}

def _unwrapZodSchema(schema_obj: any, depth: int = 0) -> any {
    max_depth = 10;
    if not schema_obj or not schema_obj._def or depth >= max_depth {
        return schema_obj;
    }
    type_value = schema_obj._def.type;
    if type_value == "optional" and schema_obj._def.innerType {
        return _unwrapZodSchema(schema_obj._def.innerType, depth + 1);
    }
    if type_value == "default" and schema_obj._def.innerType {
        return _unwrapZodSchema(schema_obj._def.innerType, depth + 1);
    }
    if schema_obj._def.checks and schema_obj._def.schema {
        return _unwrapZodSchema(schema_obj._def.schema, depth + 1);
    }
    return schema_obj;
}

def _getEnumOptions(field_schema: any) -> list {
    unwrapped = _unwrapZodSchema(field_schema);
    if unwrapped and unwrapped._def and unwrapped._def.entries {
        return Object.keys(unwrapped._def.entries);
    }
    if unwrapped and unwrapped.def and unwrapped.def.entries {
        return Object.keys(unwrapped.def.entries);
    }
    return [];
}

impl JacForm(props: dict) -> JsxElement {
    schema = props.schema;
    onSubmit = props.onSubmit;
    validate_mode = props.validateMode || "onTouched";
    submitLabel = props.submitLabel || "Submit";
    field_config = props.field_config || {};
    actualSchema = schema;
    try {
        if schema._def and schema._def.schema {
            actualSchema = schema._def.schema;
        }
    } except Exception { }
    schemaShape = actualSchema.shape || {};
    fieldNames = Object.keys(schemaShape);
    form = useJacForm(validate_mode, schema);
    errors = form.formState.errors;
    isSubmitting = form.formState.isSubmitting;
    isDirty = form.formState.isDirty;
    [passwordVisible, setPasswordVisible] = useState({});
    def _fieldErrorMessage(field_name: str) -> str {
        err = errors[field_name] if errors and errors[field_name] else None;
        if not err {
            return "";
        }
        if err.message {
            return str(err.message);
        }
        return "Invalid value";
    }
    fields = [];
    for fieldName in fieldNames {
        config = field_config[fieldName] if field_config[fieldName] else {};
        label = config.label or fieldName;
        placeholder = config.placeholder or "";
        field_type = str(config.type or config.key or "text");
        field_schema = schemaShape[fieldName];
        field_options = _getEnumOptions(field_schema);
        if field_type == "text"
        and ("password" in fieldName.lower() or "pass" in fieldName.lower()) {
            field_type = "password";
        }
        current_value = form.watch(fieldName);
        selected_value = "" if current_value == None else str(current_value);
        message = _fieldErrorMessage(fieldName);
        is_password = field_type == "password";
        is_visible = passwordVisible[fieldName] == True if passwordVisible else False;
        secure = is_password and not is_visible;
        field = form.register(fieldName, {});
        on_change = lambda text: any { form.setValue(
            fieldName,
            text,
            {"shouldDirty": True, "shouldTouch": True, "shouldValidate": True}
        ); };
        input_row: JsxElement;
        if field_type == "select" {
            option_children = [];
            if placeholder and selected_value == "" {
                option_children.append(
                    React.createElement(
                        RNText,
                        {
                            "key": "__placeholder__",
                            "style": {
                                "marginBottom": 8,
                                "color": "#6b7280",
                                "fontStyle": "italic"
                            }
                        },
                        placeholder
                    )
                );
            }
            for opt in field_options {
                opt_value = str(opt);
                is_selected = selected_value == opt_value;
                option_children.append(
                    React.createElement(
                        RNPressable,
                        {
                            "key": f"{fieldName}:{opt_value}",
                            "onPress": lambda { form.setValue(
                                fieldName,
                                opt_value,
                                {
                                    "shouldDirty": True,
                                    "shouldTouch": True,
                                    "shouldValidate": True
                                }
                            ); },
                            "style": {
                                "borderWidth": 1,
                                "borderColor": (
                                    "#2563eb" if is_selected else "#d1d5db"
                                ),
                                "paddingVertical": 10,
                                "paddingHorizontal": 12,
                                "borderRadius": 6,
                                "marginBottom": 6,
                                "backgroundColor": (
                                    "#eff6ff" if is_selected else "#ffffff"
                                )
                            }
                        },
                        React.createElement(
                            RNText, {"style": {"color": "#111827"}}, opt_value
                        )
                    )
                );
            }
            args = [RNView, {"style": {"marginTop": 2}}];
            for child in option_children {
                args.append(child);
            }
            input_row = React.createElement.apply(React, args);
        } elif field_type == "radio" {
            option_children = [];
            for opt in field_options {
                opt_value = str(opt);
                is_selected = selected_value == opt_value;
                option_children.append(
                    React.createElement(
                        RNPressable,
                        {
                            "key": f"{fieldName}:{opt_value}",
                            "onPress": lambda { form.setValue(
                                fieldName,
                                opt_value,
                                {
                                    "shouldDirty": True,
                                    "shouldTouch": True,
                                    "shouldValidate": True
                                }
                            ); },
                            "style": {
                                "flexDirection": "row",
                                "alignItems": "center",
                                "paddingVertical": 8
                            }
                        },
                        React.createElement(
                            RNText,
                            {
                                "style": {
                                    "fontSize": 16,
                                    "color": "#2563eb" if is_selected else "#9ca3af",
                                    "marginRight": 8
                                }
                            },
                            "◉" if is_selected else "○"
                        ),
                        React.createElement(
                            RNText, {"style": {"color": "#111827"}}, opt_value
                        )
                    )
                );
            }
            args = [RNView, {"style": {"marginTop": 2}}];
            for child in option_children {
                args.append(child);
            }
            input_row = React.createElement.apply(React, args);
        } else {
            input_row = React.createElement(
                RNTextInput,
                {
                    "placeholder": placeholder,
                    "value": selected_value,
                    "onChangeText": on_change,
                    "onBlur": field.onBlur,
                    "secureTextEntry": secure,
                    "style": {
                        "borderWidth": 1,
                        "borderColor": "#e5e7eb" if message == "" else "#ef4444",
                        "padding": 10,
                        "borderRadius": 6,
                        "backgroundColor": "#ffffff",
                        "flex": 1
                    }
                }
            );
        }
        if field_type == "password" {
            toggle = React.createElement(
                RNPressable,
                {
                    "onPress": lambda {
                        next_visible = Object.assign({}, passwordVisible);
                        next_visible[fieldName] = not is_visible;
                        setPasswordVisible(next_visible);
                    },
                    "style": {
                        "marginLeft": 8,
                        "paddingVertical": 8,
                        "paddingHorizontal": 10
                    }
                },
                React.createElement(
                    RNText,
                    {"style": {"color": "#2563eb", "fontWeight": "600"}},
                    "Hide" if is_visible else "Show"
                )
            );
            input_row = React.createElement(
                RNView,
                {"style": {"flexDirection": "row", "alignItems": "center"}},
                input_row,
                toggle
            );
        }
        error_view = None;
        if message != "" {
            error_view = React.createElement(
                RNText,
                {"style": {"marginTop": 4, "color": "#ef4444", "fontSize": 12}},
                message
            );
        }
        fields.append(
            React.createElement(
                RNView,
                {"key": fieldName, "style": {"marginBottom": 12}},
                React.createElement(
                    RNText, {"style": {"marginBottom": 4, "color": "#374151"}}, label
                ),
                input_row,
                error_view
            )
        );
    }
    submit_handler = lambda { form.handleSubmit(onSubmit)(); };
    args = [RNView, {"style": {"padding": 12}}];
    for f in fields {
        args.append(f);
    }
    args.append(
        React.createElement(
            RNPressable,
            {
                "onPress": submit_handler,
                "disabled": isSubmitting or not isDirty,
                "style": {
                    "backgroundColor": "#2563eb"
                        if (isDirty and not isSubmitting)
                        else "#9ca3af",
                    "padding": 12,
                    "borderRadius": 6,
                    "marginTop": 12
                }
            },
            React.createElement(
                RNText,
                {
                    "style": {
                        "color": "white",
                        "textAlign": "center",
                        "fontWeight": "600"
                    }
                },
                "Submitting..." if isSubmitting else submitLabel
            )
        )
    );
    return React.createElement.apply(React, args);
}

impl __jacInstallErrorHandlers -> None {
    __jacWirePlatformAdapters();
    if globalThis.__jacErrorHandlersInstalled {
        return;
    }
    globalThis.__jacErrorHandlersInstalled = True;
    try {
        __ensureNativeTokenPrimed();
    } except Exception { }
    try {
        prev = globalThis.ErrorUtils.getGlobalHandler();
        globalThis.ErrorUtils.setGlobalHandler(
            lambda error: any , isFatal: any {
                message = error.message if error else "Unknown error";
                stack = error.stack if error else "";
                __jacReportError(message, stack, "", "ErrorUtils");
                if prev {
                    prev(error, isFatal);
                }
            }
        );
    } except Exception as e {
        console.warn("[jac-native-runtime] Failed to install ErrorUtils handler", e);
    }
}
