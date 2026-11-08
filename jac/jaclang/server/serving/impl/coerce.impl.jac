impl RequestValidationError.__str__ -> str {
    return f"{len(self.errors)} validation error(s)";
}

impl _mismatch(expected: str, value: any) -> ValueError {
    kind = _JSON_KINDS.get(type(value), type(value).__name__);
    return ValueError(f"expected {expected}, got {kind}");
}

impl _coerce_bool(value: any, text: bool) -> bool {
    if isinstance(value, bool) {
        return value;
    }
    if not (text and isinstance(value, str)) {
        raise _mismatch('boolean', value);
    }
    word = value.strip().lower();
    if word in _TRUE_STRINGS {
        return True;
    }
    if word in _FALSE_STRINGS {
        return False;
    }
    raise ValueError('invalid boolean');
}

impl _coerce_int(value: any, text: bool) -> int {
    if isinstance(value, int) and not isinstance(value, bool) {
        return value;
    }
    if isinstance(value, float)
        and value.is_integer()
        and abs(value) <= _MAX_EXACT_FLOAT_INT {
        return int(value);
    }
    if text and isinstance(value, str) and _INT_TEXT.fullmatch(value) {
        return int(value);
    }
    raise _mismatch('integer', value);
}

impl _coerce_float(value: any, text: bool) -> float {
    is_number = isinstance(value, (int, float)) and not isinstance(value, bool);
    is_numeric_text = text and isinstance(value, str) and _FLOAT_TEXT.fullmatch(value);
    if not (is_number or is_numeric_text) {
        raise _mismatch('number', value);
    }
    parsed = float(value);
    if not isfinite(parsed) {
        raise ValueError('expected a finite number');
    }
    return parsed;
}

impl _coerce_string_type(value: any, target: type) -> any {
    try {
        return _STRING_PARSERS[target](value);
    } except Exception {
        raise ValueError(f"invalid {target.__name__}") from None;
    }
}

impl _coerce_literal(value: any, options: tuple[object, ...], text: bool) -> any {
    for opt in options {
        if opt is None or value is None {
            if opt is value {
                return opt;
            }
            continue;
        }
        try {
            if coerce_value(value, type(opt), text) == opt {
                return opt;
            }
        } except Exception {
            continue;
        }
    }
    allowed = ', '.join([repr(opt) for opt in options]);
    raise ValueError(f"expected one of {allowed}");
}

impl _coerce_tuple(
    value: any, args: tuple[object, ...], text: bool
) -> tuple[any, ...] {
    items = _as_item_list(value, text);
    if len(args) == 2 and args[1] is Ellipsis {
        return tuple(coerce_value(v, args[0], text) for v in items);
    }
    if len(items) != len(args) {
        raise ValueError(f"expected {len(args)} items, got {len(items)}");
    }
    return tuple(coerce_value(v, t, text) for (v, t) in zip(items, args));
}

impl _coerce_dict(value: any, args: tuple[object, ...], text: bool) -> dict[any, any] {
    if not isinstance(value, dict) {
        raise _mismatch('object', value);
    }
    key_t = args[0] if args else None;
    val_t = args[1] if len(args) > 1 else None;
    bound: dict[any, any] = {};
    for (k, v) in value.items() {
        key = coerce_value(k, key_t, text=True);
        if key in bound {
            raise ValueError('two keys parse to the same value');
        }
        bound[key] = coerce_value(v, val_t, text);
    }
    return bound;
}

impl _construct_object(value: any, target: any) -> any {
    if isinstance(value, target) {
        return value;
    }
    from_dict_fn: any = target?.from_dict;
    if from_dict_fn is not None {
        return from_dict_fn(value);
    }
    if not isinstance(value, dict) {
        raise ValueError(f"expected object for {getattr(target, '__name__', target)}");
    }
    init_fn = getattr(target, '__init__');
    hints: dict[str, any] = {};
    try {
        hints = get_type_hints(init_fn);
    } except Exception {
        hints = {};
    }
    sig = inspect.signature(target);
    kwargs: dict[str, any] = {};
    for (pname, param) in sig.parameters.items() {
        if param.kind
            in (inspect.Parameter.VAR_POSITIONAL, inspect.Parameter.VAR_KEYWORD) {
            continue;
        }
        if pname in value {
            kwargs[pname] = coerce_value(value[pname], hints.get(pname));
        } elif param.`default is inspect.Parameter.empty {
            raise ValueError(f"missing required field '{pname}'");
        }
    }
    return target(**kwargs);
}

impl _as_item_list(value: any, text: bool) -> list[any] {
    if isinstance(value, list) {
        return value;
    }
    if text {
        return [value];
    }
    raise _mismatch('array', value);
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

impl coerce_value(value: any, target: any = None, text: bool = False) -> any {
    if isinstance(value, UploadFile) {
        return value;
    }
    if target is None or target is typing.Any or target is inspect.Parameter.empty {
        return value;
    }
    if isinstance(target, str) {
        named = _NAME_TYPES.get(target.lower());
        if named is None {
            return value;
        }
        return coerce_value(value, named, text);
    }
    origin = get_origin(target);
    if origin is Union or origin is UnionType {
        return _coerce_union(value, get_args(target), text);
    }
    if origin is typing.Literal {
        return _coerce_literal(value, get_args(target), text);
    }
    if value is None {
        raise ValueError(
            f"null is not allowed for {getattr(target, '__name__', str(target))}"
        );
    }
    shape = origin if origin is not None else target;
    args = get_args(target);
    if shape is list {
        item_t = args[0] if args else None;
        return [coerce_value(v, item_t, text) for v in _as_item_list(value, text)];
    }
    if shape is set {
        item_t = args[0] if args else None;
        return {coerce_value(v, item_t, text) for v in _as_item_list(value, text)};
    }
    if shape is tuple {
        if target is tuple or target is typing.Tuple {
            return tuple(_as_item_list(value, text));
        }
        return _coerce_tuple(value, args, text);
    }
    if shape is dict {
        return _coerce_dict(value, args, text);
    }
    if origin is not None {
        return value;
    }
    if target is bool {
        return _coerce_bool(value, text);
    }
    if target is int {
        return _coerce_int(value, text);
    }
    if target is float {
        return _coerce_float(value, text);
    }
    if target is str {
        if isinstance(value, str) {
            return value;
        }
        raise _mismatch('string', value);
    }
    if target is bytes {
        if isinstance(value, str) {
            return value.encode();
        }
        raise _mismatch('string', value);
    }
    if target is UploadFile
        or (isinstance(target, type) and issubclass(target, UploadFile)) {
        raise _mismatch('a file', value);
    }
    if isinstance(target, EnumMeta) {
        if isinstance(value, target) {
            return value;
        }
        members: list[any] = list(target);
        try {
            return target(
                _coerce_literal(value, tuple(m.value for m in members), text)
            );
        } except ValueError {
            raise ValueError(f"invalid {target.__name__}") from None;
        }
    }
    if isinstance(target, type) and target in _STRING_PARSERS {
        return _coerce_string_type(value, target);
    }
    if isinstance(target, type) {
        for base in (int, float, str) {
            if issubclass(target, base) {
                return target(coerce_value(value, base, text));
            }
        }
    }
    if isinstance(target, type)
        and not issubclass(target, (list, dict, tuple, set))
        and (is_record(target) or hasattr(target, '__init__')) {
        return _construct_object(value, target);
    }
    return value;
}

impl _coerce_union(value: any, options: tuple[object, ...], text: bool) -> any {
    none_type = type(None);
    if value is None {
        for opt in options {
            if opt is none_type {
                return None;
            }
        }
    }
    if not text and type(value) in options {
        return coerce_value(value, type(value));
    }
    last_error: (Exception | None) = None;
    for opt in options {
        if opt is none_type {
            continue;
        }
        try {
            return coerce_value(value, opt, text);
        } except Exception as e {
            last_error = e;
        }
    }
    if last_error is not None {
        raise last_error;
    }
    return value;
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

impl _text_values(values: list[str]) -> any {
    return values if len(values) > 1 else values[0];
}

impl _extract_raw(
    param: APIParameter, request: Request, body_json: any
) -> tuple[bool, any, bool] {
    if param.kind == ParameterType.PATH {
        if param.name in request.path_params {
            return (True, request.path_params[param.name], True);
        }
        return (False, None, False);
    }
    if param.kind == ParameterType.QUERY {
        values = request.query_params.getlist(param.name);
        if values {
            return (True, _text_values(values), True);
        }
        return (False, None, False);
    }
    if param.kind == ParameterType.HEADER {
        header_val = _header_lookup(request, param.name);
        if header_val is not None {
            return (True, header_val, True);
        }
        return (False, None, False);
    }
    if param.kind == ParameterType.FILE {
        files = request.upload_files.get(param.name, []);
        if files {
            target = _without_none(_param_target(param));
            if get_origin(target) is list {
                return (True, files, False);
            }
            return (True, files[0], False);
        }
        return (False, None, False);
    }
    if param.kind == ParameterType.BODY {
        if request.form_fields and param.name in request.form_fields {
            form_values = request.form_fields[param.name];
            return (True, _text_values(form_values), True);
        }
        if isinstance(body_json, dict) and param.name in body_json {
            return (True, body_json[param.name], False);
        }
        files = request.upload_files.get(param.name, []);
        target = _param_target(param);
        if files and _accepts_upload(target) {
            if _accepts_upload_list(target)
                and (len(files) > 1 or not _accepts_single_upload(target)) {
                return (True, files, False);
            }
            return (True, files[0], False);
        }
        return (False, None, False);
    }
    return (False, None, False);
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
        (found, raw, text) = _extract_raw(param, request, body_json);
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
            kwargs[param.name] = coerce_value(raw, _param_target(param), text);
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
