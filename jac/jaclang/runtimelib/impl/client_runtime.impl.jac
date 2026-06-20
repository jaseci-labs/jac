# --- Public API forwarders to the framework-agnostic core -------------------
# Thin pass-throughs so `@jac/runtime` exposes the core auth/nav/spawn surface
# as typed functions (the bodies live in `client_runtime_core`). See the typed
# re-export note in `client_runtime.cl.jac`.
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

impl __jacJsx(tag: any, props: dict = {}, children: any = []) -> JsxElement {
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
        # Skip both `null` and `undefined`: a missing prop or omitted slot
        # surfaces as `undefined` in the compiled bundle, and accessing
        # `.__jacUnsafeHtml` on it would TypeError.
        if child == None or child == undefined {
            continue;
        }
        # `unsafe_html(...)` sentinel: wrap in a <span dangerouslySetInnerHTML>
        # so the raw markup renders inline with surrounding siblings. Property
        # access on primitives (string / number / boolean) returns `undefined`
        # in JS, so the check naturally rejects non-marker children -- no
        # `typeof` / `__isObject` guard needed. Both `null` and `undefined`
        # children were filtered above, so this access is safe.
        if child.__jacUnsafeHtml != undefined {
            reactChildren.append(
                React.createElement(
                    "span",
                    {"dangerouslySetInnerHTML": {"__html": child.__jacUnsafeHtml}}
                )
            );
        } else {
            reactChildren.append(child);
        }
    }
    if len(reactChildren) > 0 {
        args = [tag, props];
        for child in reactChildren {
            args.append(child);
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

"""Auth guard component for file-based routing. Renders child routes if
authenticated, otherwise redirects to the login path."""
impl AuthGuard(redirect: str = "/login") -> JsxElement {
    if jacIsLoggedIn() {
        return <ReactRouterOutlet/>;
    }
    return <ReactRouterNavigate to={redirect} replace={True}/>;
}

# Thin wrapper over React.Suspense for the `awaiting` template clause.
# When a child throws a Promise (the React Suspense protocol), the
# `fallback` element renders until the Promise settles. `flow`/`wait`
# don't throw Promises today, so the fallback only appears when the
# try-body itself opts into a Suspense-aware primitive (e.g. `use()`,
# a fetcher that suspends). The wrapper is still useful as the named
# integration point so the language-level lowering stays stable.
impl JacAwaiting(props: dict) -> JsxElement {
    return React.createElement(
        React.Suspense, {"fallback": props.fallback}, props.children
    );
}

impl ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement {
    # Reporting happens in __jacReactErrorHandler (the boundary's onError prop)
    # which is the only place React exposes `info.componentStack`.
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
        # onChange-only (same as Solid): errors are always fresh when values change.
        # isTouched gate in renderError ensures errors show only after first blur.
        # Wiring both onChange+onBlur leaves stale onBlur entries in other fields'
        # errorMap after cross-field interaction (TanStack #1784), keeping
        # isValid=false even after those fields have been corrected.
        validators["onChange"] = schema;
    } else {
        console.warn(f"Unknown validateMode '{form_mode}'; falling back to onBlur");
        validators["onBlur"] = schema;
    }
    opts = {"defaultValues": defaults, "validators": validators};
    if onSubmit {
        opts["onSubmit"] = lambda args: any { return onSubmit(args.value); };
    }
    return useForm(opts);
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
    [passwordVisible, setPasswordVisible] = useState({});
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
        fieldType: str, field: any, config: dict, fieldSchema: any, fieldName: str
    ) -> JsxElement {
        inputClassName = config.inputClassName or "";
        labelClassName = config.labelClassName or "";
        placeholder = config.placeholder or "";
        label = config.label or fieldName;
        hasError = (
            field.state.meta.errors
            and field.state.meta.errors.length
            and (validateMode != "onTouched" or field.state.meta.isTouched)
        );

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
                        name={fieldName}
                        checked={field.state.value || False}
                        onChange={lambda e: any { field.handleChange(
                            e.target.checked
                        ); }}
                        onBlur={field.handleBlur}
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
                    name={fieldName}
                    value={field.state.value || ""}
                    onChange={lambda e: any { field.handleChange(e.target.value); }}
                    onBlur={field.handleBlur}
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
                                name={fieldName}
                                value={opt}
                                checked={field.state.value == opt}
                                onChange={lambda e: any { field.handleChange(
                                    e.target.value
                                ); }}
                                onBlur={field.handleBlur}
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
                    name={fieldName}
                    placeholder={placeholder}
                    rows={rows}
                    value={field.state.value}
                    onChange={lambda e: any { field.handleChange(e.target.value); }}
                    onBlur={field.handleBlur}
                    className={inputClassName}
                    style={{
                        width: "100%",
                        boxSizing: "border-box",
                        border: (
                            "2px solid #ef4444" if hasError else "2px solid #e5e7eb"
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
            isVisible = passwordVisible[fieldName] || False;
            return (
                <div>
                    <div style={{position: "relative"}}>
                        <input
                            type={"text" if isVisible else "password"}
                            name={fieldName}
                            placeholder={placeholder}
                            value={field.state.value}
                            onChange={lambda e: any { field.handleChange(
                                e.target.value
                            ); }}
                            onBlur={field.handleBlur}
                            className={inputClassName}
                            style={{
                                width: "100%",
                                boxSizing: "border-box",
                                border: (
                                    "2px solid #ef4444"
                                        if hasError
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
                name={fieldName}
                placeholder={placeholder}
                value={field.state.value}
                onChange={lambda e: any { field.handleChange(
                    parseFloat(e.target.value)
                        if fieldType == "number"
                        else e.target.value
                ); }}
                onBlur={field.handleBlur}
                className={inputClassName}
                style={{
                    width: "100%",
                    boxSizing: "border-box",
                    border: ("2px solid #ef4444" if hasError else "2px solid #e5e7eb")
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
                        {renderError(
                            field.state.meta.errors, field.state.meta.isTouched
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
                selector={lambda s: any { return {
                    isDirty: s.isDirty,
                    isValid: s.isValid,
                    isTouched: s.isTouched,
                    isSubmitting: s.isSubmitting
                }; }}
            >
                {lambda fs: JsxElement {
                    # onTouched: treat form as valid before any field is touched so the
                    # eager onChange validator does not disable the button prematurely.
                    btnEffectiveIsValid = (
                        True
                            if (validateMode == "onTouched" and not fs.isTouched)
                            else fs.isValid
                    );
                    btnDisabled = (
                        fs.isSubmitting or not fs.isDirty or not btnEffectiveIsValid
                    );
                    return (
                        <button
                            type="submit"
                            disabled={btnDisabled}
                            className={buttonClassName}
                            style={{
                                width: "100%",
                                cursor: ("not-allowed" if btnDisabled else "pointer")
                            }}
                        >
                            {fs.isSubmitting and "Submitting..."}{not fs.isSubmitting
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
impl __jacReactErrorHandler(error: any, info: any) -> None {
    try {
        message = error.message if error else "Unknown error";
        stack = error.stack if error else "";
        componentStack = info.componentStack if info else "";
        __jacReportError(message, stack, "", "ErrorBoundary", componentStack);
    } except Exception {
    # Silent: error reporting from a React lifecycle must never throw.
    }
}
