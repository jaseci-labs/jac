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
        if child == None or child == undefined {
            continue;
        }

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

impl AuthGuard(redirect: str = "/login") -> JsxElement {
    if jacIsLoggedIn() {
        return <ReactRouterOutlet/>;
    }
    return <ReactRouterNavigate to={redirect} replace={True}/>;
}

impl JacAwaiting(props: dict) -> JsxElement {
    return React.createElement(
        React.Suspense, {"fallback": props.fallback}, props.children
    );
}

impl useJacForm(form_mode: str, schema: any, onSubmit: any = None) -> any {
    actualSchema = __unwrapFormSchema(schema);
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
        validators["onChange"] = schema;
    } else {
        console.warn(f"Unknown validateMode '{form_mode}'; falling back to onBlur");
        validators["onBlur"] = schema;
    }
    opts = {"defaultValues": defaults, "validators": validators};
    if onSubmit {
        opts["onSubmit"] = lambda (args: any) { return onSubmit(args.value); };
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
    actualSchema = __unwrapFormSchema(schema);
    schemaShape = actualSchema.shape || {};
    fieldNames = Object.keys(schemaShape);
    form = useJacForm(validateMode, schema, onSubmit);
    [passwordVisible, setPasswordVisible] = useState({});
    def unwrapZodSchema(schema: any, depth: int = 0) -> any {
        maxDepth = 10;
        if depth >= maxDepth {
            return schema;
        }

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

        if unwrapped.options and Array.isArray(unwrapped.options) {
            return unwrapped.options;
        }

        if unwrapped.enum {
            return Object.keys(unwrapped.enum);
        }

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
                        onChange={lambda (e: any) { field.handleChange(
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
                    onChange={lambda (e: any) { field.handleChange(e.target.value); }}
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
                                onChange={lambda (e: any) { field.handleChange(
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
                    onChange={lambda (e: any) { field.handleChange(e.target.value); }}
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
                            onChange={lambda (e: any) { field.handleChange(
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
                            onChange={lambda (e: any) { setPasswordVisible(
                                lambda (prev: any) -> dict {
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
                onChange={lambda (e: any) { field.handleChange(
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
                {lambda (field: JsxElement) { return (
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
            onSubmit={lambda (e: any) {
                e.preventDefault();
                e.stopPropagation();
                form.handleSubmit();
            }}
            className={formClassName}
        >
            <div style={layoutStyle}>{fields}</div>
            <form.Subscribe
                selector={lambda (s: any) { return {
                    isDirty: s.isDirty,
                    isValid: s.isValid,
                    isTouched: s.isTouched,
                    isSubmitting: s.isSubmitting
                }; }}
            >
                {lambda (fs: JsxElement) {
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
