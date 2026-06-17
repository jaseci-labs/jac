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

# ============================================================================
# Router bindings — adapters bridging react-router-dom's shape onto @solidjs/router
# ============================================================================
# `Router`, `useNavigate`, `useLocation`, `useParams` are re-exported verbatim
# (see the glob block in the shim); only the components whose prop shape diverges
# are adapted here.
"""Adapter for react-router-dom's `<Routes>`, which has no `@solidjs/router`
equivalent — Solid expects `<Route>` elements as direct children of `<Router>`.
This passthrough renders its children so React-shaped `<Router><Routes>...`
source still lowers. Deeply nested route *matching* through this wrapper is a
documented best-effort gap pending browser e2e."""
impl Routes(props: dict) -> JsxElement {
    return props.children;
}

"""Adapter mapping react-router-dom's `<Route element={<C/>}>` onto
`@solidjs/router`'s `<Route component={C}>`: the already-built element is wrapped
in a thunk component so Solid can mount it. `path`/`children` pass through."""
impl Route(props: dict) -> JsxElement {
    routeProps = {};
    if props.path != undefined {
        routeProps["path"] = props.path;
    }
    if props.element != undefined {
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

"""`@solidjs/router` has no `<Outlet>`; nested route content is delivered to a
parent route's `component` via `props.children`. v1 renders any children handed
in; true nested-layout outlet semantics are a documented gap pending browser
e2e."""
impl Outlet(props: dict = {}) -> JsxElement {
    if props != undefined {
        return props.children;
    }
    return None;
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

"""Auth guard for file-based routing. Renders nested route content when
authenticated, else redirects to the login path. Mirrors the React shim's
`AuthGuard`; the `Outlet` path inherits the v1 outlet gap above."""
impl AuthGuard(redirect: str = "/login") -> JsxElement {
    if jacIsLoggedIn() {
        return Outlet();
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
# Forms (solid-hook-form + zod)
# ============================================================================
"""Minimal zod resolver in the shape `@hookform/resolvers/zod` produces, so the
Solid build needs no `@hookform` package (kept out by the runtime-split purity
scan). Returns a react-hook-form-style resolver: validates via `schema.safeParse`
and maps zod issues to `{ [dotted.path]: { type, message } }`. `solid-hook-form`
calls the resolver with the form values (extra args are ignored)."""
impl __zodResolver(schema: any) -> any {
    return lambda values: any -> dict {
        result = schema.safeParse(values);
        if result.success {
            return {"values": result.data, "errors": {}};
        }
        errors = {};
        for issue in result.error.issues {
            path = issue.path.join(".");
            if not errors[path] {
                errors[path] = {"type": issue.code, "message": issue.message};
            }
        }
        return {"values": {}, "errors": errors};
    };
}

"""Create a form controller over `solid-hook-form`'s `createForm`, mirroring the
React shim's `useJacForm` (`react-hook-form`'s `useForm`). `createForm` requires
`defaultValues`, so empty string defaults are derived from the (unwrapped) zod
schema shape. Validation runs through the hand-rolled `__zodResolver`."""
impl useJacForm(form_mode: str, schema: any) -> any {
    actualSchema = schema;
    try {
        if schema._def and schema._def.schema {
            actualSchema = schema._def.schema;
        }
    } except Exception as e {
        console.warn("Failed to unwrap schema:", e);
    }
    schemaShape = actualSchema.shape || {};
    defaults = {};
    for key in Object.keys(schemaShape) {
        defaults[key] = "";
    }
    return createForm(
        {
            "defaultValues": defaults,
            "mode": form_mode,
            "resolver": __zodResolver(schema)
        }
    );
}

"""Schema-driven form component, ported from the React shim's `JacForm` onto
`solid-hook-form`. The prop contract is identical (schema, onSubmit, layout,
field_config, submitLabel, ...). Solid divergences from react-hook-form handled
here: `form.watch(x)` → `form.values()[x]`; `formState.isDirty` is an accessor
(`isDirty()`); there is no `formState.isSubmitting`, so a local `createSignal`
tracks it around the submit; `useState` → `createSignal`."""
impl JacForm(props: dict) -> JsxElement {
    # Destructure props (JSX passes all props as a single object)
    schema = props.schema;
    onSubmit = props.onSubmit;
    layout = props.layout || "vertical";
    field_config = props.field_config || {};
    submitLabel = props.submitLabel || "Submit";
    submitClassName = props.submitClassName || "";
    gridColumns = props.gridColumns || 2;
    validateMode = props.validateMode || "onTouched";
    className = props.className || "";
    # Extract field names from schema
    # Handle ZodEffects (schemas with .refine()) by unwrapping
    actualSchema = schema;
    try {
        if schema._def and schema._def.schema {
            # This is a ZodEffects, unwrap to get the base schema
            actualSchema = schema._def.schema;
        }
    } except Exception as e {
        console.warn("Failed to unwrap schema:", e);
    }
    schemaShape = actualSchema.shape || {};
    fieldNames = Object.keys(schemaShape);
    # Initialize form with the original schema (not the unwrapped one)
    form = useJacForm(validateMode, schema);
    errors = form.formState.errors;
    # solid-hook-form exposes `isDirty` as an accessor; there is no
    # `isSubmitting`, so track it locally around the async submit.
    isDirty = form.formState.isDirty;
    [isSubmitting, setIsSubmitting] = solidCreateSignal(False);
    # State for password visibility (separate state for each field)
    [passwordVisible, setPasswordVisible] = solidCreateSignal({});
    # Wrap the user's onSubmit so the submit button can reflect in-flight state.
    # An inner `async def` (not a lambda) is required so the `await` lowers to an
    # `async` function — `solid-hook-form`'s `handleSubmit` awaits the returned
    # promise.
    async def submitHandler(values: any) {
        setIsSubmitting(True);
        try {
            await onSubmit(values);
        } finally {
            setIsSubmitting(False);
        }
    }
    # Helper function to recursively unwrap Zod wrapper types
    def unwrapZodSchema(schema: any, depth: int = 0) -> any {
        maxDepth = 10;  # Prevent infinite recursion
        if not schema._def or depth >= maxDepth {
            return schema;
        }

        typeValue = schema._def.type;

        # Unwrap ZodOptional (.optional())
        if typeValue == "optional" and schema._def.innerType {
            return unwrapZodSchema(schema._def.innerType, depth + 1);
        }

        # Unwrap ZodDefault (.default())
        if typeValue == "default" and schema._def.innerType {
            return unwrapZodSchema(schema._def.innerType, depth + 1);
        }

        # Unwrap ZodEffects (.refine(), .transform(), etc.)
        if schema._def.checks and schema._def.schema {
            return unwrapZodSchema(schema._def.schema, depth + 1);
        }

        # Base case: not a wrapper type
        return schema;
    }
    # Helper: Render error message
    def renderError(error: any) -> JsxElement | None {
        if not error {
            return None;
        }
        return (
            <p style={{color: "#ef4444", fontSize: "0.85rem", marginTop: "0.25rem"}}>
                ⚠️{error.message}
            </p>
        );
    }
    # Helper: Extract enum options from schema
    def getEnumOptions(fieldSchema: any) -> list {
        unwrapped = unwrapZodSchema(fieldSchema);
        if unwrapped._def and unwrapped._def.entries {
            return Object.keys(unwrapped._def.entries);
        } elif unwrapped.def and unwrapped.def.entries {
            return Object.keys(unwrapped.def.entries);
        }
        return [];
    }
    # Helper: Render the actual input element based on type
    def renderInput(
        fieldType: str,
        field: any,
        error: any,
        config: dict,
        fieldSchema: any,
        fieldName: str
    ) -> JsxElement {
        inputClassName = config.inputClassName or "";
        labelClassName = config.labelClassName or "";
        placeholder = config.placeholder or "";
        label = config.label or fieldName;

        # Checkbox
        if fieldType == "checkbox" {
            watchValue = form.values()[fieldName];
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
                        name={field.name}
                        ref={field.ref}
                        onChange={field.onChange}
                        onBlur={field.onBlur}
                        checked={watchValue || False}
                        className={inputClassName}
                        style={{cursor: "pointer"}}
                    />
                    <span className={labelClassName}>{label}</span>
                </label>
            );
        }

        # Select dropdown
        if fieldType == "select" {
            options = getEnumOptions(fieldSchema);
            watchValue = form.values()[fieldName];
            return (
                <select
                    name={field.name}
                    ref={field.ref}
                    onChange={field.onChange}
                    onBlur={field.onBlur}
                    value={watchValue || ""}
                    className={inputClassName}
                    style={{width: "100%", boxSizing: "border-box"}}
                >
                    <option value="">{placeholder or f"Select {label}"}</option>
                    {[<option value={opt} key={opt}>{opt}</option> for opt in options]}
                </select>
            );
        }

        # Radio buttons
        if fieldType == "radio" {
            options = getEnumOptions(fieldSchema);
            watchValue = form.values()[fieldName];
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
                                name={field.name}
                                value={opt}
                                ref={field.ref}
                                onChange={field.onChange}
                                onBlur={field.onBlur}
                                checked={watchValue == opt}
                                className={inputClassName}
                                style={{cursor: "pointer"}}
                            />
                            <span>{opt}</span>
                        </label> for opt in options
                    ]}
                </div>
            );
        }

        # Textarea
        if fieldType == "textarea" {
            rows = config.rows or 4;
            return (
                <textarea
                    placeholder={placeholder}
                    rows={rows}
                    {**field}
                    className={inputClassName}
                    style={{
                        width: "100%",
                        boxSizing: "border-box",
                        border: ("2px solid #ef4444" if error else "2px solid #e5e7eb"),
                        padding: "0.5rem",
                        fontFamily: "inherit",
                        fontSize: "inherit",
                        resize: "vertical"
                    }}
                />
            );
        }

        # Regular input (text, email, password, number, date, datetime-local, tel, url, etc.)
        # Special handling for password fields with visibility toggle
        if fieldType == "password" and config.showPasswordToggle {
            isVisible = passwordVisible()[fieldName] || False;
            return (
                <div>
                    <div style={{position: "relative"}}>
                        <input
                            type={"text" if isVisible else "password"}
                            placeholder={placeholder}
                            {**field}
                            className={inputClassName}
                            style={{
                                width: "100%",
                                boxSizing: "border-box",
                                border: (
                                    "2px solid #ef4444"
                                        if error
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

        # Regular input without toggle
        return (
            <input
                type={fieldType}
                placeholder={placeholder}
                {**field}
                className={inputClassName}
                style={{
                    width: "100%",
                    boxSizing: "border-box",
                    border: ("2px solid #ef4444" if error else "2px solid #e5e7eb")
                }}
            />
        );
    }
    # Main field renderer
    def renderField(fieldName: str) -> JsxElement {
        fieldSchema = schemaShape[fieldName];
        config = field_config[fieldName] if field_config[fieldName] else {};

        # field_config entries carry the input kind under a "type" key
        # (e.g. {type: "email"}); read it straight through.
        fieldType = config.type or "text";
        label = config.label or fieldName;
        fieldClassName = config.className or "";
        labelClassName = config.labelClassName or "";

        # Register field and get error state
        # valueAsNumber: true is required for number fields because <input type="number">
        registerOptions = {"valueAsNumber": True} if fieldType == "number" else {};
        field = form.register(fieldName, registerOptions);

        # `errors[fieldName]` is read *inline* (not captured in a const) so the
        # read happens inside the thunks `lower_view_expr` wraps these dynamic
        # children in — `solid-hook-form`'s `formState.errors` is a reactive
        # store, so per-field messages then live-update without a re-render.
        # Render: wrapper > input > error
        return (
            <div
                className={fieldClassName}
                style={{marginBottom: "1rem"}}
                key={fieldName}
            >
                <label
                    className={labelClassName}
                    style={{display: "block", marginBottom: "0.5rem"}}
                >
                    {label}
                </label>
                {renderInput(
                    fieldType, field, errors[fieldName], config, fieldSchema, fieldName
                )}
                {renderError(errors[fieldName])}
            </div>
        );
    }
    # Generate layout styles based on layout prop
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
            # vertical (default)
            return {};
        }
    }
    # Render all fields
    fields = [];
    for fieldName in fieldNames {
        fields.append(renderField(fieldName));
    }
    layoutStyle = getLayoutStyle();
    formClassName = className or "";
    buttonClassName = submitClassName or "";
    return (
        <form onSubmit={form.handleSubmit(submitHandler)} className={formClassName}>
            <div style={layoutStyle}>{fields}</div>
            <button
                type="submit"
                disabled={isSubmitting() or not isDirty()}
                className={buttonClassName}
                style={{
                    width: "100%",
                    cursor: (
                        "not-allowed"
                            if (isSubmitting() or not isDirty())
                            else "pointer"
                    )
                }}
            >
                {isSubmitting() and "Submitting..."}{not isSubmitting() and submitLabel}
            </button>
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
