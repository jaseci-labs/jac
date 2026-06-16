# --- Public API forwarders to the framework-agnostic core -------------------
# Thin pass-throughs so `@jac/runtime` exposes the core auth/nav/spawn surface
# as typed functions (the bodies live in `client_runtime_core`). See the typed
# re-export note in `solid_runtime.cl.jac`. Identical to the React shim's
# forwarders — only the JSX factory below diverges.
impl navigate(path: str) -> None {
    _navigate(path);
}

impl jacSpawn(left: str, right: str = "", fields: dict = {}) -> any {
    return _jacSpawn(left, right, fields);
}

impl jacSignup(
    identities_or_username: (str | list),
    credential_or_password: (str | dict),
    profile: (dict | None) = None
) -> dict {
    return await _jacSignup(identities_or_username, credential_or_password, profile);
}

impl jacLogin(
    identity_or_username: (str | dict), credential_or_password: (str | dict)
) -> bool {
    return await _jacLogin(identity_or_username, credential_or_password);
}

impl jacLogout -> None {
    _jacLogout();
}

impl jacIsLoggedIn -> bool {
    return _jacIsLoggedIn();
}

impl jacSsoLogin(platform: str, api_base: str = "", operation: str = "login") -> bool {
    return await _jacSsoLogin(platform, api_base, operation);
}

impl jacSetToken(token: str) -> None {
    _jacSetToken(token);
}

# --- Solid JSX factory ------------------------------------------------------
# Mirrors the React `__jacJsx` shape but lowers to Solid's hyperscript runtime
# (`h(tag, props, ...children)`) instead of `React.createElement`. The contract
# is identical: filter `null`/`undefined` children, honor the `unsafe_html`
# sentinel, and spread children as trailing args.
impl __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement {
    childrenArray = [];
    if children != None {
        if Array.isArray(children) {
            childrenArray = children;
        } else {
            childrenArray = [children];
        }
    }
    solidChildren = [];
    for child in childrenArray {
        # Skip both `null` and `undefined`: a missing prop or omitted slot
        # surfaces as `undefined` in the compiled bundle, and accessing
        # `.__jacUnsafeHtml` on it would TypeError.
        if child == None or child == undefined {
            continue;
        }
        # `unsafe_html(...)` sentinel: render the raw markup inline via Solid's
        # `innerHTML` prop on a wrapping <span> (Solid's equivalent of React's
        # `dangerouslySetInnerHTML`). Property access on primitives returns
        # `undefined`, so the check naturally rejects non-marker children.
        if child.__jacUnsafeHtml != undefined {
            solidChildren.append(h("span", {"innerHTML": child.__jacUnsafeHtml}));
        } else {
            solidChildren.append(child);
        }
    }
    # A null tag is a fragment: Solid renders a plain array of children inline,
    # so no `Fragment` import is needed (unlike React.Fragment).
    if tag == None {
        return solidChildren;
    }
    if len(solidChildren) > 0 {
        args = [tag, props];
        for child in solidChildren {
            args.append(child);
        }
        return h.apply(None, args);
    }
    return h(tag, props);
}
