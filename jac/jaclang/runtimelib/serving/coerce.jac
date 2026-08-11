import inspect;
import from dataclasses { is_dataclass }
import from enum { EnumMeta }
import from types { UnionType }
import from typing { Any, Union, get_args, get_origin, get_type_hints }
import from jaclang.runtimelib.serving.datatypes { Request, UploadFile }
import from jaclang.runtimelib.serving.endpoint {
    APIParameter,
    JEndPoint,
    ParameterType
}


obj RequestValidationError(Exception) {
    has errors: list[dict] = [];

    def __str__ -> str {
        return f"{len(self.errors)} validation error(s)";
    }
}

glob _TRUE_STRINGS: set[str] = {'1', 'true', 'yes', 'on', 'y'},
     _FALSE_STRINGS: set[str] = {'0', 'false', 'no', 'off', 'n', ''},
     _NAME_TYPES: dict[str, any] = {
         'str': str,
         'string': str,
         'int': int,
         'integer': int,
         'float': float,
         'number': float,
         'bool': bool,
         'boolean': bool,
         'list': list,
         'array': list,
         'dict': dict,
         'object': dict,
         'any': None,
         '': None
     };


def _coerce_bool(value: any) -> bool {
    if isinstance(value, bool) {
        return value;
    }
    text = str(value).strip().lower();
    if text in _TRUE_STRINGS {
        return True;
    }
    if text in _FALSE_STRINGS {
        return False;
    }
    raise ValueError(f"invalid boolean: {value!r}");
}

def _construct_object(value: any, target: any) -> any {
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
    sig = inspect.signature(init_fn);
    kwargs: dict[str, any] = {};
    for (pname, param) in sig.parameters.items() {
        if pname in ('self', 'args', 'kwargs') {
            continue;
        }
        if pname in value {
            kwargs[pname] = coerce_value(value[pname], hints.get(pname));
        } elif param.default is inspect.Parameter.empty {
            raise ValueError(f"missing required field '{pname}'");
        }
    }
    return target(**kwargs);
}

def _as_item_list(value: any) -> list {
    if isinstance(value, (list, tuple, set)) {
        return list(value);
    }
    return [value];
}

def coerce_value(value: any, target: any = None) -> any {
    if isinstance(value, UploadFile) {
        return value;
    }
    if target is None or target is Any or target is inspect.Parameter.empty {
        return value;
    }
    if isinstance(target, str) {
        named = _NAME_TYPES.get(target.lower());
        if named is None {
            return value;
        }
        return coerce_value(value, named);
    }
    origin = get_origin(target);
    if origin is not None {
        args = get_args(target);
        if origin is Union or origin is UnionType {
            return _coerce_union(value, args);
        }
        if origin is list {
            item_t = args[0] if args else None;
            return [coerce_value(v, item_t) for v in _as_item_list(value)];
        }
        if origin is dict {
            if not isinstance(value, dict) {
                raise ValueError(f"expected object, got {type(value).__name__}");
            }
            val_t = args[1] if len(args) > 1 else None;
            return {k: coerce_value(v, val_t) for (k, v) in value.items()};
        }
        if origin is tuple {
            return tuple(
                coerce_value(v, args[i] if i < len(args) else None)
                for (i, v) in enumerate(_as_item_list(value))
            );
        }
        if origin is set {
            item_t = args[0] if args else None;
            return {coerce_value(v, item_t) for v in _as_item_list(value)};
        }
        return value;
    }
    if target is bool {
        return _coerce_bool(value);
    }
    if target is int {
        return int(value);
    }
    if target is float {
        return float(value);
    }
    if target is str {
        return value if isinstance(value, str) else str(value);
    }
    if target is bytes {
        return value if isinstance(value, bytes) else str(value).encode();
    }
    if target is UploadFile
        or (isinstance(target, type) and issubclass(target, UploadFile)) {
        return value;
    }
    if isinstance(target, EnumMeta) {
        if isinstance(value, target) {
            return value;
        }
        return target(value);
    }
    if isinstance(target, type)
        and not issubclass(
            target, (str, int, float, bool, bytes, list, dict, tuple, set)
        )
        and (is_dataclass(target) or hasattr(target, '__init__')) {
        return _construct_object(value, target);
    }
    return value;
}

def _coerce_union(value: any, options: tuple) -> any {
    none_type = type(None);
    if value is None {
        for opt in options {
            if opt is none_type {
                return None;
            }
        }
    }
    last_error: (Exception | None) = None;
    for opt in options {
        if opt is none_type {
            continue;
        }
        try {
            return coerce_value(value, opt);
        } except Exception as e {
            last_error = e;
        }
    }
    if last_error is not None {
        raise last_error;
    }
    return value;
}

def _param_target(param: APIParameter) -> any {
    if param.type_obj is not None {
        return param.type_obj;
    }
    return param.data_type;
}

def _header_lookup(request: Request, name: str) -> (str | None) {
    direct = request.headers.get(name);
    if direct is not None {
        return direct;
    }
    return request.headers.get(name.replace('_', '-'));
}

def _extract_raw(
    param: APIParameter, request: Request, body_json: any
) -> tuple[bool, Any] {
    if param.kind == ParameterType.PATH {
        if param.name in request.path_params {
            return (True, request.path_params[param.name]);
        }
        return (False, None);
    }
    if param.kind == ParameterType.QUERY {
        target = _param_target(param);
        if get_origin(target) is list {
            values = request.query_params.getlist(param.name);
            if values {
                return (True, values);
            }
            return (False, None);
        }
        if param.name in request.query_params {
            return (True, request.query_params.get(param.name));
        }
        return (False, None);
    }
    if param.kind == ParameterType.HEADER {
        header_val = _header_lookup(request, param.name);
        if header_val is not None {
            return (True, header_val);
        }
        return (False, None);
    }
    if param.kind == ParameterType.FILE {
        files = request.upload_files.get(param.name, []);
        if files {
            target = _param_target(param);
            if get_origin(target) is list {
                return (True, files);
            }
            return (True, files[0]);
        }
        return (False, None);
    }
    if param.kind == ParameterType.BODY {
        if request.form_fields and param.name in request.form_fields {
            form_values = request.form_fields[param.name];
            if len(form_values) == 1 {
                return (True, form_values[0]);
            }
            return (True, form_values);
        }
        if isinstance(body_json, dict) and param.name in body_json {
            return (True, body_json[param.name]);
        }
        return (False, None);
    }
    return (False, None);
}

def _fresh_default(value: any) -> any {
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

def bind_parameters(ep: JEndPoint, request: Request, body_json: any) -> dict[str, Any] {
    kwargs: dict[str, Any] = {};
    errors: list[dict] = [];
    declared: set[str] = set();
    for param in (ep.parameters or []) {
        declared.add(param.name);
        loc = str(param.kind.value)
            if isinstance(param.kind, ParameterType)
            else str(param.kind);
        (found, raw) = _extract_raw(param, request, body_json);
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
            kwargs[param.name] = coerce_value(raw, _param_target(param));
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

obj CallbackSpec {
    has names: set[str] = set(),
        body_candidates: list[str] = [],
        accepts_var_kw: bool = False,
        wants_request: bool = False,
        introspectable: bool = True,
        is_async: bool = False;
}

def build_callback_spec(callback: any) -> CallbackSpec {
    is_async = inspect.iscoroutinefunction(callback);
    try {
        sig = inspect.signature(callback);
    } except (TypeError, ValueError) {
        return CallbackSpec(introspectable=False, is_async=is_async);
    }
    names: set[str] = set();
    body_candidates: list[str] = [];
    accepts_var_kw = False;
    for (pname, param) in sig.parameters.items() {
        if param.kind == inspect.Parameter.VAR_KEYWORD {
            accepts_var_kw = True;
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
        introspectable=True,
        is_async=is_async
    );
}

def get_callback_spec(ep: JEndPoint) -> CallbackSpec {
    if ep.callback_spec is None {
        ep.callback_spec = build_callback_spec(ep.callback);
    }
    return ep.callback_spec;
}

def body_param_name(spec: CallbackSpec, bound: dict[str, any]) -> (str | None) {
    for pname in spec.body_candidates {
        if pname not in bound {
            return pname;
        }
    }
    return None;
}

def filter_kwargs_for_callback(
    spec: CallbackSpec, kwargs: dict[str, Any], request: Request
) -> dict[str, Any] {
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
