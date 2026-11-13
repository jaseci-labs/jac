impl type_shape(target: object) -> tuple[object, tuple[object, ...]] {
    hit = _SHAPES.get(id(target));
    if hit is not None and hit[0] is target {
        return (hit[1], hit[2]);
    }
    origin = get_origin(target);
    args = get_args(target);
    if len(_SHAPES) >= _SHAPES_LIMIT {
        _SHAPES.clear();
    }
    _SHAPES[id(target)] = (target, origin, args);
    return (origin, args);
}

impl convert(value: any, target: any, mode: ConvertMode = ConvertMode.STRICT) -> any {
    if target is None or target is typing.Any or type(value) is target {
        return value;
    }
    if isinstance(target, str) {
        raise TypeError(f"unresolved annotation {target!r}");
    }
    (origin, args) = type_shape(target);
    if origin is Union or origin is UnionType {
        return _convert_union(value, args, mode);
    }
    base = origin if origin is not None else target;
    if not isinstance(base, type) or (origin is not None and base not in _CONTAINERS) {
        return value;
    }
    if value is None {
        raise ValueError(
            f"null is not allowed for {getattr(target, '__name__', str(target))}"
        );
    }
    if mode == ConvertMode.LENIENT and isinstance(value, base) {
        return value;
    }
    if base in _CONTAINERS {
        return _convert_container(value, base, args, mode);
    }
    return _convert_class(value, base, mode);
}

impl _mismatch(expected: str, value: any) -> ValueError {
    return ValueError(f"expected {expected}, got {type(value).__name__}");
}

impl _convert_union(value: any, members: tuple[any, ...], mode: ConvertMode) -> any {
    if value is None and (NoneType in members or mode == ConvertMode.LENIENT) {
        return None;
    }
    last_error: (Exception | None) = None;
    for member in members {
        if member is NoneType {
            continue;
        }
        try {
            return convert(value, member, mode);
        } except Exception as e {
            last_error = e;
        }
    }
    raise last_error if last_error is not None else _mismatch('union member', value);
}

impl _convert_container(
    value: any, base: type, args: tuple[any, ...], mode: ConvertMode
) -> any {
    if mode == ConvertMode.LENIENT {
        if base is tuple and isinstance(value, list) {
            return tuple(value);
        }
        if base is list and isinstance(value, tuple) {
            return list(value);
        }
        raise _mismatch('object' if base is dict else 'array', value);
    }
    if base is dict {
        if not isinstance(value, dict) {
            raise _mismatch('object', value);
        }
        value_t = args[1] if len(args) > 1 else None;
        return {k: convert(v, value_t, mode) for (k, v) in value.items()};
    }
    if isinstance(value, (list, tuple, set)) {
        items = list(value);
    } elif mode == ConvertMode.TEXT {
        items = [value];
    } else {
        raise _mismatch('array', value);
    }
    if base is tuple {
        return tuple(
            convert(v, args[i] if i < len(args) else None, mode)
            for (i, v) in enumerate(items)
        );
    }
    item_t = args[0] if args else None;
    if base is set {
        return {convert(v, item_t, mode) for v in items};
    }
    return [convert(v, item_t, mode) for v in items];
}

impl _convert_class(value: any, target: type, mode: ConvertMode) -> any {
    sized = target?.__jac_sized__;
    if isinstance(sized, str) {
        return _to_sized(value, target, sized, mode);
    }
    if target is bool {
        return _to_bool(value, mode);
    }
    if target is int or target is float {
        return _to_number(value, target, mode);
    }
    if target is str {
        if isinstance(value, str) {
            return value;
        }
        if mode == ConvertMode.LENIENT {
            return str(value);
        }
        raise _mismatch('string', value);
    }
    if target is bytes {
        if isinstance(value, bytes) {
            return value;
        }
        if isinstance(value, str) {
            return value.encode();
        }
        raise _mismatch('string', value);
    }
    if issubclass(target, Enum) {
        return _to_enum(value, target, mode);
    }
    if target in STRING_FORMATS {
        if isinstance(value, target) {
            return value;
        }
        if not isinstance(value, str) {
            raise _mismatch('string', value);
        }
        return UUID(value)
            if target is UUID
            else getattr(target, 'fromisoformat')(value);
    }
    if mode == ConvertMode.LENIENT {
        raise _mismatch(target.__name__, value);
    }
    if issubclass(target, (str, int, float, bytes, list, dict, tuple, set)) {
        return value;
    }
    return _construct(value, target, mode);
}

impl _to_bool(value: any, mode: ConvertMode) -> bool {
    if isinstance(value, bool) {
        return value;
    }
    if isinstance(value, str) and mode != ConvertMode.STRICT {
        word = value.strip().lower();
        if word in _TRUE_WORDS {
            return True;
        }
        if word in _FALSE_WORDS {
            return False;
        }
        raise ValueError(f"invalid boolean: {value!r}");
    }
    if isinstance(value, (int, float)) and mode == ConvertMode.LENIENT {
        return bool(value);
    }
    raise _mismatch('boolean', value);
}

impl _to_number(value: any, kind: type, mode: ConvertMode) -> any {
    expected = 'integer' if kind is int else 'number';
    if isinstance(value, str) and mode != ConvertMode.STRICT {
        return kind(value);
    }
    lossy = isinstance(value, bool)
        or (kind is int and isinstance(value, float) and not value.is_integer());
    if not isinstance(value, (int, float)) or (lossy and mode != ConvertMode.LENIENT) {
        raise _mismatch(expected, value);
    }
    return kind(value);
}

impl _to_sized(value: any, target: type, name: str, mode: ConvertMode) -> any {
    if mode == ConvertMode.STRICT and isinstance(value, str) {
        wide = json_wire_read(name, value);
        if json_wire_form(name, wide) == value {
            return wide;
        }
    }
    core = _to_number(value, float if issubclass(target, float) else int, mode);
    return json_wire_read(name, core);
}

impl _to_enum(value: any, target: type[Enum], mode: ConvertMode) -> any {
    if isinstance(value, target) {
        return value;
    }
    try {
        return target(value);
    } except (ValueError, KeyError) {
        if mode == ConvertMode.LENIENT and isinstance(value, str) {
            return target[value];
        }
        raise;
    }
}

impl _construct(value: any, target: any, mode: ConvertMode) -> any {
    if isinstance(value, target) {
        return value;
    }
    if hasattr(target, 'from_dict') {
        return target.from_dict(value);
    }
    if not isinstance(value, dict) {
        raise ValueError(f"expected object for {target.__name__}");
    }
    hints: dict[str, any] = {};
    try {
        hints = get_type_hints(target.__init__);
    } except Exception {}
    kwargs: dict[str, any] = {};
    for (pname, param) in inspect.signature(target).parameters.items() {
        if param.kind
            in (inspect.Parameter.VAR_POSITIONAL, inspect.Parameter.VAR_KEYWORD) {
            continue;
        }
        if pname in value {
            kwargs[pname] = convert(value[pname], hints.get(pname), mode);
        } elif param.`default is inspect.Parameter.empty {
            raise ValueError(f"missing required field '{pname}'");
        }
    }
    return target(**kwargs);
}
