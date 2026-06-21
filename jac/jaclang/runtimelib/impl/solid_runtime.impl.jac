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

# ============================================================================
# Router bindings — adapters bridging react-router-dom's shape onto @solidjs/router
# ============================================================================
# `Router`, `useNavigate`, `useLocation`, `useParams` are re-exported verbatim
# (see the glob block in the shim); only the components whose prop shape diverges
# are adapted here.
"""Adapter for react-router-dom's `<Routes>`, which has no `@solidjs/router`
equivalent — `@solidjs/router`'s `<Router>` consumes `<Route>` children as its
config directly. The generated file-based-routing entry therefore renders routes
straight under `<Router>` (no `<Routes>`). This passthrough is kept only for
cross-framework surface parity; hand-written `<Router><Routes>...` source still
lowers, but route *matching* through the wrapper is best-effort — prefer the
native form."""
impl Routes(props: dict) -> JsxElement {
    return props.children;
}

"""Adapter mapping react-router-dom's `<Route element={<C/>}>` onto
`@solidjs/router`'s `<Route component={C}>`. The native `component` prop is
preferred (Solid then delivers nested/auth route content to the component as
`props.children`); a React-shape `element` is wrapped in a thunk component as a
documented best-effort fallback for hand-written source. `path`/`children` pass
through."""
impl Route(props: dict) -> JsxElement {
    routeProps = {};
    if props.path != undefined {
        routeProps["path"] = props.path;
    }
    if props.component != undefined {
        routeProps["component"] = props.component;
    } elif props.element != undefined {
        routeProps["component"] = lambda -> any { return props.element; };
    }
    if props.children != undefined {
        routeProps["children"] = props.children;
    }
    return SolidRoute(routeProps);
}

"""Adapter mapping react-router-dom's `<Link to=...>` onto `@solidjs/router`'s
`<A href=...>`. All other props (className, style, children, ...) pass through."""
impl Link(props: dict) -> JsxElement {
    anchorProps = {};
    for key in Object.keys(props) {
        if key != "to" {
            anchorProps[key] = props[key];
        }
    }
    anchorProps["href"] = props.to;
    return SolidAnchor(anchorProps);
}

"""Adapter mapping react-router-dom's `<Navigate to=... replace>` onto
`@solidjs/router`'s `<Navigate href=...>`. Solid's `Navigate` always replaces, so
the `replace` prop is accepted but redundant (documented)."""
impl Navigate(props: dict) -> JsxElement {
    navProps = {"href": props.to};
    if props.state != undefined {
        navProps["state"] = props.state;
    }
    return SolidNavigate(navProps);
}

"""`@solidjs/router` has no `<Outlet>`; it delivers the matched nested route to a
parent/layout route's `component` as `props.children`. Jac layouts are authored
`def layout -> JsxElement` (no params) and place `<Outlet/>` where children go, so
the matched content can't reach them through their own props. `__jacMakeLayoutRoot`
publishes the route props on `__JacOutletContext`; this reads `.children` back so
the layout's `<Outlet/>` resolves. Outside a provider the context default `None`
falls through to any direct `props.children`."""
impl Outlet(props: dict = {}) -> JsxElement {
    ctx = solidUseContext(__JacOutletContext);
    if ctx != None and ctx != undefined {
        return ctx.children;
    }
    if props != undefined {
        return props.children;
    }
    return None;
}

"""Wrap a Jac layout component as a `@solidjs/router` `<Router root=...>` layout.
Solid renders `root` once as the app shell and hands the matched route to it as
`props.children`; this publishes those props on `__JacOutletContext` and renders
the (param-less) layout, so the layout's `<Outlet/>` reads the children back."""
impl __jacMakeLayoutRoot(layout_component: any) -> any {
    return lambda props: any -> JsxElement {
        LayoutComponent = layout_component;
        return (
            <__JacOutletContext.Provider value={props}>
                <LayoutComponent/>
            </__JacOutletContext.Provider>
        );
    };
}

"""Composed router hook — mirrors the React shim's `useRouter`, returning the
same `{navigate, location, params, pathname, search, hash}` dict so call sites
are framework-identical. Backed by `@solidjs/router`'s reactive primitives."""
impl useRouter -> dict {
    navigate = solidUseNavigate();
    location = solidUseLocation();
    params = solidUseParams();
    return {
        "navigate": navigate,
        "location": location,
        "params": params,
        "pathname": location.pathname,
        "search": location.search,
        "hash": location.hash
    };
}

"""Auth guard for file-based routing. Used as a pathless parent route's
`component`, so `@solidjs/router` passes the matched protected route in as
`children`: render it when authenticated, else redirect to the login path.
Mirrors the React shim's `AuthGuard` (whose `<Outlet/>` plays the same role)."""
impl AuthGuard(redirect: str = "/login", children: any = None) -> JsxElement {
    if jacIsLoggedIn() {
        return children;
    }
    return Navigate({"to": redirect, "replace": True});
}

# ============================================================================
# Error boundary + async boundary
# ============================================================================
"""Presents react-error-boundary's API ({FallbackComponent, onError, children})
over `solid-js`'s `<ErrorBoundary fallback={(err, reset) => ...}>`, so the same
React-shaped boundary call sites work on Solid. `onError` (when supplied) is
invoked before the fallback renders; Solid's fallback has no `componentStack`,
so an empty one is passed through to keep the reporting signature stable."""
impl JacClientErrorBoundary(props: dict) -> JsxElement {
    def fallback(err: any, reset: any) -> any {
        if props.onError != undefined {
            props.onError(err, {"componentStack": ""});
        }
        if props.FallbackComponent != undefined {
            return props.FallbackComponent({"error": err, "resetErrorBoundary": reset});
        }
        return None;
    }
    return SolidErrorBoundary({"fallback": fallback, "children": props.children});
}

"""Default error fallback UI. Solid (like react-error-boundary) calls the
fallback with a single props object, so the first parameter `error` carries
`{error, resetErrorBoundary}` - accessed as `error.error.message` /
`error.resetErrorBoundary()`, matching the React shim verbatim."""
impl ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement {
    return
        <div
            role="alert"
            style={{
                minHeight: "100vh",
                display: "flex",
                justifyContent: "center",
                alignItems: "center",
                backgroundColor: "#f9fafb",
                fontFamily: "system-ui, sans-serif",

            }}
        >
            <div
                role="alert"
                style={{
                    minHeight: "100vh",
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "center",
                    alignItems: "center",
                    backgroundColor: "#f9fafb",
                    fontFamily: "system-ui, sans-serif",

                }}
            >
                <h2 style={{color: "#dc2626", marginBottom: "12px"}}>
                    🚨 Something went wrong
                </h2>
                <p style={{color: "#374151", marginBottom: "16px"}}>
                    An unexpected error occurred. Please try again.
                </p>
                <pre
                    style={{
                        color: "#991b1b",
                        background: "#fee2e2",
                        padding: "12px",
                        borderRadius: "8px",
                        fontSize: "14px",
                        overflowX: "auto",
                        marginBottom: "16px",

                    }}
                >
                    {error.error.message}
                </pre>
                <button
                    onClick={lambda { error.resetErrorBoundary(); }}
                    style={{
                        backgroundColor: "#2563eb",
                        color: "#fff",
                        padding: "10px 16px",
                        borderRadius: "8px",
                        border: "none",
                        cursor: "pointer",
                        fontSize: "14px",

                    }}
                >
                    🔄 Try again
                </button>
            </div>
        </div>;
}

"""Full-screen compilation-error overlay (HMR). Framework-neutral JSX (lowers
through `__jacJsx`), identical to the React shim's `errorOverlay`."""
impl errorOverlay(filePath: str, errors: str) -> JsxElement {
    return (
        <div
            style={{
                position: "fixed",
                top: 0,
                left: 0,
                width: "100%",
                height: "100%",
                background: "rgba(0, 0, 0, 0.85)",
                color: "#fff",
                fontFamily: "'Monaco', 'Menlo', 'Ubuntu Mono', monospace",
                fontSize: 14,
                zIndex: 999999,
                overflow: "auto",
                padding: 20,
                boxSizing: "border-box",

            }}
        >
            <div style={{maxWidth: 1200, margin: "0 auto"}}>
                <div
                    style={{
                        background: "#d32f2f",
                        color: "white",
                        padding: "16px 24px",
                        borderRadius: "8px 8px 0 0",
                        fontSize: 18,
                        fontWeight: "bold",

                    }}
                >
                    ⚠️ Compilation Error
                </div>
                <div
                    style={{
                        background: "#1e1e1e",
                        padding: 24,
                        borderRadius: "0 0 8px 8px",

                    }}
                >
                    <div style={{marginBottom: 16}}>
                        <div style={{color: "#888", marginBottom: 8}}>File:</div>
                        <div style={{color: "#64b5f6", fontWeight: "bold"}}>
                            {filePath}
                        </div>
                    </div>
                    <div>
                        <div style={{color: "#888", marginBottom: 8}}>Error:</div>
                        <pre
                            style={{
                                background: "#2d2d2d",
                                padding: 16,
                                borderRadius: 4,
                                overflowX: "auto",
                                margin: 0,
                                borderLeft: "4px solid #d32f2f",
                                lineHeight: 1.6,
                                color: "#ff6b6b",

                            }}
                        >
                            {errors}
                        </pre>
                    </div>
                    <div
                        style={{
                            marginTop: 24,
                            paddingTop: 16,
                            borderTop: "1px solid #444",
                            color: "#888",
                            fontSize: 13,

                        }}
                    >
                        💡 Fix the error and save the file to continue development.
                    </div>
                </div>
            </div>
        </div>
    );
}

"""Async-boundary wrapper for the `try { ...await... } awaiting {...}` clause —
a thin wrapper over `solid-js`'s `<Suspense fallback={...}>`. Mirrors the React
shim's `JacAwaiting` (which wraps `React.Suspense`)."""
impl JacAwaiting(props: dict) -> JsxElement {
    return SolidSuspense({"fallback": props.fallback, "children": props.children});
}

# ============================================================================
# Forms (@tanstack/solid-form + zod)
# ============================================================================
impl useJacForm(form_mode: str, schema: any, onSubmit: any = None) -> any {
    actualSchema = schema;
    try {
        if not schema.shape {
            if schema._def and schema._def.schema {
                actualSchema = schema._def.schema;
            } elif schema.def and schema.def.schema {
                actualSchema = schema.def.schema;
            }
        }
    } except Exception as e {
        console.warn("Failed to unwrap schema:", e);
    }
    schemaShape = actualSchema.shape || {};
    defaults = {};
    for key in Object.keys(schemaShape) {
        defaults[key] = "";
    }
    validators = {};
    if form_mode == "onChange" {
        validators["onChange"] = schema;
    } elif form_mode == "onSubmit" {
        validators["onSubmit"] = schema;
    } elif form_mode == "onBlur" {
        validators["onBlur"] = schema;
    } elif form_mode == "onTouched" {
        # Only onChange so errors are always fresh when values change. The error
        # display is gated on isTouched so errors appear only after blur. Using
        # both onChange+onBlur leaves stale onBlur entries in other fields'
        # errorMap (set when the first field blurs), keeping isValid=false even
        # after those fields have valid values.
        validators["onChange"] = schema;
    } else {
        console.warn(f"Unknown validateMode '{form_mode}'; falling back to onBlur");
        validators["onBlur"] = schema;
    }
    opts = {"defaultValues": defaults, "validators": validators};
    if onSubmit {
        opts["onSubmit"] = lambda args: any { return onSubmit(args.value); };
    }
    f = createForm(lambda -> any { return opts; });
    return f;
}

impl JacForm(props: dict) -> JsxElement {
    schema = props.schema;
    onSubmit = props.onSubmit;
    layout = props.layout || "vertical";
    field_config = props.field_config || {};
    submitLabel = props.submitLabel || "Submit";
    submitClassName = props.submitClassName || "";
    gridColumns = props.gridColumns || 2;
    validateMode = props.validateMode || "onTouched";
    className = props.className || "";
    actualSchema = schema;
    try {
        if not schema.shape {
            if schema._def and schema._def.schema {
                actualSchema = schema._def.schema;
            } elif schema.def and schema.def.schema {
                actualSchema = schema.def.schema;
            }
        }
    } except Exception as e {
        console.warn("Failed to unwrap schema:", e);
    }
    schemaShape = actualSchema.shape || {};
    fieldNames = Object.keys(schemaShape);
    form = useJacForm(validateMode, schema, onSubmit);
    [passwordVisible, setPasswordVisible] = solidCreateSignal({});
    def unwrapZodSchema(schema: any, depth: int = 0) -> any {
        maxDepth = 10;
        if depth >= maxDepth {
            return schema;
        }
        # Prefer public Zod methods (optional/nullable expose .unwrap())
        try {
            if schema.unwrap {
                return unwrapZodSchema(schema.unwrap(), depth + 1);
            }
        } except Exception { }
        if not schema._def {
            return schema;
        }
        typeValue = schema._def.type;
        if typeValue == "optional" and schema._def.innerType {
            return unwrapZodSchema(schema._def.innerType, depth + 1);
        }
        if typeValue == "default" and schema._def.innerType {
            return unwrapZodSchema(schema._def.innerType, depth + 1);
        }
        if schema._def.checks and schema._def.schema {
            return unwrapZodSchema(schema._def.schema, depth + 1);
        }
        return schema;
    }
    def renderError(errors: list, isTouched: bool) -> JsxElement | None {
        if validateMode == "onTouched" and not isTouched {
            return None;
        }
        if not errors or not errors.length {
            return None;
        }
        return (
            <p style={{color: "#ef4444", fontSize: "0.85rem", marginTop: "0.25rem"}}>
                ⚠️{errors[0].message}
            </p>
        );
    }
    def getEnumOptions(fieldSchema: any) -> list {
        unwrapped = unwrapZodSchema(fieldSchema);
        # Public Zod v3/v4 API: z.enum() exposes .options array
        if unwrapped.options and Array.isArray(unwrapped.options) {
            return unwrapped.options;
        }
        # Public Zod v3 API: z.nativeEnum() exposes .enum object
        if unwrapped.enum {
            return Object.keys(unwrapped.enum);
        }
        # Fallback: Zod v4 internal _def.entries / def.entries
        if unwrapped._def and unwrapped._def.entries {
            return Object.keys(unwrapped._def.entries);
        }
        if unwrapped.def and unwrapped.def.entries {
            return Object.keys(unwrapped.def.entries);
        }
        return [];
    }
    def renderInput(
        fieldType: str, fieldApi: any, config: dict, fieldSchema: any, fieldName: str
    ) -> JsxElement {
        inputClassName = config.inputClassName or "";
        labelClassName = config.labelClassName or "";
        placeholder = config.placeholder or "";
        label = config.label or fieldName;

        if fieldType == "checkbox" {
            return (
                <label
                    style={{
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "0.5rem"
                    }}
                >
                    <input
                        type="checkbox"
                        checked={fieldApi().state.value || False}
                        onInput={lambda e: any { fieldApi().handleChange(
                            e.target.checked
                        ); }}
                        onChange={lambda e: any { fieldApi().handleChange(
                            e.target.checked
                        ); }}
                        onBlur={fieldApi().handleBlur}
                        className={inputClassName}
                        style={{cursor: "pointer"}}
                    />
                    <span className={labelClassName}>{label}</span>
                </label>
            );
        }

        if fieldType == "select" {
            options = getEnumOptions(fieldSchema);
            return (
                <select
                    value={fieldApi().state.value || ""}
                    onInput={lambda e: any { fieldApi().handleChange(e.target.value); }}
                    onChange={lambda e: any { fieldApi().handleChange(
                        e.target.value
                    ); }}
                    onBlur={fieldApi().handleBlur}
                    className={inputClassName}
                    style={{width: "100%", boxSizing: "border-box"}}
                >
                    <option value="">{placeholder or f"Select {label}"}</option>
                    {[<option value={opt} key={opt}>{opt}</option> for opt in options]}
                </select>
            );
        }

        if fieldType == "radio" {
            options = getEnumOptions(fieldSchema);
            return (
                <div style={{display: "flex", flexDirection: "column", gap: "0.5rem"}}>
                    {[
                        <label
                            key={opt}
                            style={{
                                cursor: "pointer",
                                display: "flex",
                                alignItems: "center",
                                gap: "0.5rem"
                            }}
                        >
                            <input
                                type="radio"
                                value={opt}
                                checked={fieldApi().state.value == opt}
                                onInput={lambda e: any { fieldApi().handleChange(
                                    e.target.value
                                ); }}
                                onChange={lambda e: any { fieldApi().handleChange(
                                    e.target.value
                                ); }}
                                onBlur={fieldApi().handleBlur}
                                className={inputClassName}
                                style={{cursor: "pointer"}}
                            />
                            <span>{opt}</span>
                        </label> for opt in options
                    ]}
                </div>
            );
        }

        if fieldType == "textarea" {
            rows = config.rows or 4;
            return (
                <textarea
                    placeholder={placeholder}
                    rows={rows}
                    value={fieldApi().state.value}
                    onChange={lambda e: any { fieldApi().handleChange(
                        e.target.value
                    ); }}
                    onBlur={fieldApi().handleBlur}
                    className={inputClassName}
                    style={{
                        width: "100%",
                        boxSizing: "border-box",
                        border: (
                            "2px solid #ef4444"
                                if (
                                    fieldApi().state.meta.errors
                                    and fieldApi().state.meta.errors.length
                                    and (
                                        validateMode != "onTouched"
                                        or fieldApi().state.meta.isTouched
                                    )
                                )
                                else "2px solid #e5e7eb"
                        ),
                        padding: "0.5rem",
                        fontFamily: "inherit",
                        fontSize: "inherit",
                        resize: "vertical"
                    }}
                />
            );
        }

        if fieldType == "password" and config.showPasswordToggle {
            isVisible = passwordVisible()[fieldName] || False;
            return (
                <div>
                    <div style={{position: "relative"}}>
                        <input
                            type={"text" if isVisible else "password"}
                            placeholder={placeholder}
                            value={fieldApi().state.value}
                            onChange={lambda e: any { fieldApi().handleChange(
                                e.target.value
                            ); }}
                            onBlur={fieldApi().handleBlur}
                            className={inputClassName}
                            style={{
                                width: "100%",
                                boxSizing: "border-box",
                                border: (
                                    "2px solid #ef4444"
                                        if (
                                            fieldApi().state.meta.errors
                                            and fieldApi().state.meta.errors.length
                                            and (
                                                validateMode != "onTouched"
                                                or fieldApi().state.meta.isTouched
                                            )
                                        )
                                        else "2px solid #e5e7eb"
                                ),
                                paddingRight: "2.5rem"
                            }}
                        />
                    </div>
                    <label
                        style={{
                            cursor: "pointer",
                            display: "flex",
                            alignItems: "center",
                            gap: "0.5rem",
                            marginTop: "0.5rem",
                            fontSize: "0.875rem",
                            color: "#6b7280"
                        }}
                    >
                        <input
                            type="checkbox"
                            checked={isVisible}
                            onChange={lambda e: any { setPasswordVisible(
                                lambda prev: any -> dict {
                                    newState = Object.assign({}, prev);
                                    newState[fieldName] = not isVisible;
                                    return newState;
                                }
                            ); }}
                            style={{cursor: "pointer"}}
                        />
                        <span>Show password</span>
                    </label>
                </div>
            );
        }

        return (
            <input
                type={fieldType}
                placeholder={placeholder}
                value={fieldApi().state.value}
                onInput={lambda e: any { fieldApi().handleChange(
                    parseFloat(e.target.value)
                        if fieldType == "number"
                        else e.target.value
                ); }}
                onChange={lambda e: any { fieldApi().handleChange(
                    parseFloat(e.target.value)
                        if fieldType == "number"
                        else e.target.value
                ); }}
                onBlur={fieldApi().handleBlur}
                className={inputClassName}
                style={{
                    width: "100%",
                    boxSizing: "border-box",
                    border: (
                        "2px solid #ef4444"
                            if (
                                fieldApi().state.meta.errors
                                and fieldApi().state.meta.errors.length
                                and (
                                    validateMode != "onTouched"
                                    or fieldApi().state.meta.isTouched
                                )
                            )
                            else "2px solid #e5e7eb"
                    )
                }}
            />
        );
    }
    def renderField(fieldName: str) -> JsxElement {
        fieldSchema = schemaShape[fieldName];
        config = field_config[fieldName] if field_config[fieldName] else {};
        fieldType = config.type or "text";
        label = config.label or fieldName;
        fieldClassName = config.className or "";
        labelClassName = config.labelClassName or "";

        return (
            <form.Field name={fieldName} key={fieldName}>
                {lambda field: JsxElement { return (
                    <div className={fieldClassName} style={{marginBottom: "1rem"}}>
                        <label
                            className={labelClassName}
                            style={{display: "block", marginBottom: "0.5rem"}}
                        >
                            {label}
                        </label>
                        {renderInput(fieldType, field, config, fieldSchema, fieldName)}
                        {(
                            (
                                validateMode != "onTouched"
                                or field().state.meta.isTouched
                            )
                            and not field().state.meta.isValid
                            and field().state.meta.errors
                            and field().state.meta.errors.length
                        )
                        and (
                            <p
                                style={{
                                    color: "#ef4444",
                                    fontSize: "0.85rem",
                                    marginTop: "0.25rem"
                                }}
                            >
                                ⚠️{field().state.meta.errors[0].message}
                            </p>
                        )}
                    </div>
                ); }}
            </form.Field>
        );
    }
    def getLayoutStyle -> dict {
        if layout == "grid" {
            return {
                display: "grid",
                gridTemplateColumns: f"repeat({gridColumns}, 1fr)",
                gap: "1rem"
            };
        } elif layout == "horizontal" {
            return {
                display: "flex",
                gap: "1rem",
                flexWrap: "wrap",
                alignItems: "flex-start"
            };
        } elif layout == "inline" {
            return {display: "flex", gap: "0.5rem", alignItems: "flex-end"};
        } else {
            return {};
        }
    }
    fields = [];
    for fieldName in fieldNames {
        fields.append(renderField(fieldName));
    }
    layoutStyle = getLayoutStyle();
    formClassName = className or "";
    buttonClassName = submitClassName or "";
    return (
        <form
            onSubmit={lambda e: any {
                e.preventDefault();
                e.stopPropagation();
                form.handleSubmit();
            }}
            className={formClassName}
        >
            <div style={layoutStyle}>{fields}</div>
            <form.Subscribe
                selector={lambda state: any { return [
                    state.isSubmitting,
                    state.isDirty,
                    state.isValid,
                    state.isTouched
                ]; }}
            >
                {lambda snap: any {
                    isDisabled = createMemo(
                        lambda -> any {
                            _s = snap();
                            isSubmitting = _s[0];
                            isDirty = _s[1];
                            isValid = _s[2];
                            isTouched = _s[3];
                            return (
                                isSubmitting
                                or not isDirty
                                or (
                                    (validateMode != "onTouched" or isTouched)
                                    and not isValid
                                )
                            );
                        }
                    );
                    isSubmittingM = createMemo(lambda -> any { return snap()[0]; });
                    return (
                        <button
                            type="submit"
                            disabled={isDisabled()}
                            className={buttonClassName}
                            style={{
                                width: "100%",
                                cursor: ("not-allowed" if isDisabled() else "pointer")
                            }}
                        >
                            {isSubmittingM() and "Submitting..."}{not isSubmittingM()
                            and submitLabel}
                        </button>
                    );
                }}
            </form.Subscribe>
        </form>
    );
}

# ============================================================================
# Client Error Reporting
# ============================================================================
"""Reports an error caught by the client error boundary to the server. Mirrors
the React shim's handler; named `__jacReactErrorHandler` for API parity across
frameworks. Solid's `ErrorBoundary` provides no `componentStack`, so `info` is
optional."""
impl __jacReactErrorHandler(error: any, info: any) -> None {
    try {
        message = error.message if error else "Unknown error";
        stack = error.stack if error else "";
        componentStack = info.componentStack if info else "";
        __jacReportError(message, stack, "", "ErrorBoundary", componentStack);
    } except Exception {
    # Silent: error reporting from a lifecycle hook must never throw.
    }
}
