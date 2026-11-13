impl RequestValidationError.__str__ -> str {
    return f"{len(self.errors)} validation error(s)";
}

impl is_upload_type(target: any) -> bool {
    if target is None {
        return False;
    }
    origin = get_origin(target);
    if origin is list {
        args = get_args(target);
        return len(args) == 1 and is_upload_type(args[0]);
    }
    if origin is Union or origin is UnionType {
        branches = [
            arg
            for arg in get_args(target)
            if arg is not type(None)
        ];
        return len(branches) > 0 and all([is_upload_type(arg) for arg in branches]);
    }
    if isinstance(target, type) {
        return issubclass(target, UploadFile) or target.__name__ == 'UploadFile';
    }
    return False;
}

impl _accepts_upload(target: any) -> bool {
    origin = get_origin(target);
    if origin is Union or origin is UnionType {
        return any([_accepts_upload(arg) for arg in get_args(target)]);
    }
    return is_upload_type(target);
}

impl _accepts_upload_list(target: any) -> bool {
    origin = get_origin(target);
    if origin is Union or origin is UnionType {
        return any([_accepts_upload_list(arg) for arg in get_args(target)]);
    }
    return origin is list and is_upload_type(target);
}

impl _accepts_single_upload(target: any) -> bool {
    origin = get_origin(target);
    if origin is Union or origin is UnionType {
        return any([_accepts_single_upload(arg) for arg in get_args(target)]);
    }
    return origin is not list and is_upload_type(target);
}

impl _without_none(target: any) -> any {
    origin = get_origin(target);
    if origin is Union or origin is UnionType {
        args = [
            arg
            for arg in get_args(target)
            if arg is not type(None)
        ];
        if len(args) == 1 {
            return args[0];
        }
    }
    return target;
}

impl coerce_value(
    value: any, target: any = None, mode: ConvertMode = ConvertMode.STRICT
) -> any {
    if isinstance(value, UploadFile)
        or target is inspect.Parameter.empty
        or is_upload_type(target) {
        return value;
    }
    if isinstance(target, str) {
        named = _NAME_TYPES.get(target.lower());
        return value if named is None else convert(value, named, mode);
    }
    return convert(value, target, mode);
}

impl _param_target(param: APIParameter) -> any {
    if param.type_obj is not None {
        return param.type_obj;
    }
    return param.data_type;
}

impl _header_lookup(request: Request, name: str) -> (str | None) {
    direct = request.headers.get(name);
    if direct is not None {
        return direct;
    }
    return request.headers.get(name.replace('_', '-'));
}

impl _extract_raw(
    param: APIParameter, request: Request, body_json: any
) -> tuple[bool, any, ConvertMode] {
    if param.kind == ParameterType.PATH {
        if param.name in request.path_params {
            return (True, request.path_params[param.name], ConvertMode.TEXT);
        }
        return (False, None, ConvertMode.STRICT);
    }
    if param.kind == ParameterType.QUERY {
        target = _param_target(param);
        if get_origin(target) is list {
            values = request.query_params.getlist(param.name);
            if values {
                return (True, values, ConvertMode.TEXT);
            }
            return (False, None, ConvertMode.STRICT);
        }
        if param.name in request.query_params {
            return (True, request.query_params.get(param.name), ConvertMode.TEXT);
        }
        return (False, None, ConvertMode.STRICT);
    }
    if param.kind == ParameterType.HEADER {
        header_val = _header_lookup(request, param.name);
        if header_val is not None {
            return (True, header_val, ConvertMode.TEXT);
        }
        return (False, None, ConvertMode.STRICT);
    }
    if param.kind == ParameterType.FILE {
        files = request.upload_files.get(param.name, []);
        if files {
            target = _without_none(_param_target(param));
            if get_origin(target) is list {
                return (True, files, ConvertMode.STRICT);
            }
            return (True, files[0], ConvertMode.STRICT);
        }
        return (False, None, ConvertMode.STRICT);
    }
    if param.kind == ParameterType.BODY {
        if request.form_fields and param.name in request.form_fields {
            form_values = request.form_fields[param.name];
            if len(form_values) == 1 {
                return (True, form_values[0], ConvertMode.TEXT);
            }
            return (True, form_values, ConvertMode.TEXT);
        }
        if isinstance(body_json, dict) and param.name in body_json {
            return (True, body_json[param.name], ConvertMode.STRICT);
        }
        files = request.upload_files.get(param.name, []);
        target = _param_target(param);
        if files and _accepts_upload(target) {
            if _accepts_upload_list(target)
                and (len(files) > 1 or not _accepts_single_upload(target)) {
                return (True, files, ConvertMode.STRICT);
            }
            return (True, files[0], ConvertMode.STRICT);
        }
        return (False, None, ConvertMode.STRICT);
    }
    return (False, None, ConvertMode.STRICT);
}

impl _fresh_default(value: any) -> any {
    if isinstance(value, (dict, list, set)) {
        import copy;
        try {
            return copy.deepcopy(value);
        } except Exception {
            return value;
        }
    }
    return value;
}

impl bind_parameters(
    ep: JEndPoint, request: Request, body_json: any
) -> dict[str, any] {
    kwargs: dict[str, any] = {};
    errors: list[dict[str, any]] = [];
    declared: set[str] = set();
    for param in ep.declared_parameters() {
        declared.add(param.name);
        loc = str(param.kind.value)
            if isinstance(param.kind, ParameterType)
            else str(param.kind);
        (found, raw, mode) = _extract_raw(param, request, body_json);
        if not found {
            if param.required {
                errors.append(
                    {
                        'type': 'missing',
                        'loc': [loc, param.name],
                        'msg': 'Field required'
                    }
                );
            } elif param.default_value is not None {
                kwargs[param.name] = _fresh_default(param.default_value);
            }
            continue;
        }
        try {
            kwargs[param.name] = coerce_value(raw, _param_target(param), mode);
        } except Exception as e {
            errors.append({'type': 'invalid', 'loc': [loc, param.name], 'msg': str(e)});
        }
    }
    if errors {
        raise RequestValidationError(errors=errors);
    }
    if ep.forward_undeclared_query_params {
        for name in request.query_params.keys() {
            if name not in declared and name not in kwargs {
                kwargs[name] = request.query_params.get(name);
            }
        }
    }
    return kwargs;
}

impl build_callback_spec(callback: any) -> CallbackSpec {
    is_async = inspect.iscoroutinefunction(callback);
    try {
        sig = inspect.signature(callback);
    } except (TypeError, ValueError) {
        return CallbackSpec(introspectable=False, is_async=is_async);
    }
    names: set[str] = set();
    body_candidates: list[str] = [];
    accepts_var_kw = False;
    request_positional = False;
    for (pname, param) in sig.parameters.items() {
        if param.kind == inspect.Parameter.VAR_KEYWORD {
            accepts_var_kw = True;
            continue;
        }
        if pname == 'request' and param.kind == inspect.Parameter.POSITIONAL_ONLY {
            request_positional = True;
            continue;
        }
        names.add(pname);
        if pname not in ('self', 'request')
            and param.kind
                in (
                    inspect.Parameter.POSITIONAL_OR_KEYWORD,
                    inspect.Parameter.KEYWORD_ONLY
                ) {
            body_candidates.append(pname);
        }
    }
    return CallbackSpec(
        names=names,
        body_candidates=body_candidates,
        accepts_var_kw=accepts_var_kw,
        wants_request='request' in names,
        request_positional=request_positional,
        introspectable=True,
        is_async=is_async
    );
}

impl get_callback_spec(ep: JEndPoint) -> CallbackSpec {
    if ep.callback_spec is None {
        ep.callback_spec = build_callback_spec(ep.callback);
    }
    return ep.callback_spec;
}

impl body_param_name(spec: CallbackSpec, bound: dict[str, any]) -> (str | None) {
    for pname in spec.body_candidates {
        if pname not in bound {
            return pname;
        }
    }
    return None;
}

impl filter_kwargs_for_callback(
    spec: CallbackSpec, kwargs: dict[str, any], request: Request
) -> dict[str, any] {
    if not spec.introspectable {
        return kwargs;
    }
    if spec.wants_request and 'request' not in kwargs {
        kwargs['request'] = request;
    }
    if spec.accepts_var_kw {
        return kwargs;
    }
    return {
        k: v
        for (k, v) in kwargs.items()
        if k in spec.names
    };
}
