"""Decorator that returns a random instance of the function's return type."""

impl returns_fake(func: Any) -> Any {
    try {
        type_hints = get_type_hints(
            func, globalns=func.__globals__, localns=None, include_extras=True
        );
    } except Exception {
        type_hints = getattr(func, '__annotations__', {});
    }
    ret_t = type_hints.get('return', Any);
    @wraps(func)
    def wrapper(*args: Any, **kwargs: Any) -> Any {
        return random_value_for_type(ret_t);
    }
    return wrapper;
}

"""Generate a random value that (best-effort) conforms to the type 'tp'."""
impl random_value_for_type(tp: Any, *, _depth: int = 0, _max_depth: int = 10) -> Any {
    random.seed(42);  # for reproducibility in tests
    if _depth > _max_depth {
        # Depth cap to avoid infinite recursion on self-referential types
        origin = get_origin(tp);
        if origin in (list, set, frozenset, tuple, dict, deque) {
            return origin() if origin is not tuple else tuple();
        }
        prim = _random_primitive(_unwrap_newtype(_unwrap_annotated(tp)));
        if prim is not None {
            return prim;
        }
        return None;
    }
    tp = _unwrap_newtype(_unwrap_annotated(tp));
    # Any / object => pick a simple JSON-friendly value
    if tp in (Any, object) {
        return random.choice(
            [_rand_str(), random.randint(0, 9999), True, None, random.uniform(0, 1)]
        );
    }
    # Primitives and common stdlib scalars
    prim = _random_primitive(tp);
    if prim is not None {
        return prim;
    }
    # Literal
    if get_origin(tp) is Literal {
        choices = get_args(tp);
        return _choose_from(choices);
    }
    # Union / Optional
    if get_origin(tp) is Union {
        options = list(get_args(tp));
        # Bias slightly away from None, if present
        if type(None) in options and len(options) > 1 and random.random() < 0.3 {
            return None;
        }
        chosen = _choose_from(
            [
                t
                for t in options
                if t is not type(None)
            ]
        )
        if options
        else None;
        return random_value_for_type(chosen, _depth=_depth + 1, _max_depth=_max_depth);
    }
    # Tuple (fixed-length or variadic)
    if get_origin(tp) is tuple {
        args = get_args(tp);
        if len(args) == 2 and args[1] is Ellipsis {
            # Tuple[T, ...]
            n = random.randint(0, 5);
            return tuple(
                random_value_for_type(
                    args[0], _depth=_depth + 1, _max_depth=_max_depth
                ) for _ in range(n)
            );
        } else {
            return tuple(
                random_value_for_type(a, _depth=_depth + 1, _max_depth=_max_depth)
                for a in args
            );
        }
    }
    # List / Set / FrozenSet / Deque / Dict
    origin = get_origin(tp);
    if origin in (list, set, frozenset, deque) {
        elem_type = get_args(tp)[0] if get_args(tp) else Any;
        size = random.randint(0, 5);
        elems = [
            random_value_for_type(elem_type, _depth=_depth + 1, _max_depth=_max_depth)
            for _ in range(size)
        ];
        if origin is list {
            return elems;
        }
        if origin is set {
            try {
                return set(elems);
            } except TypeError {
                return {str(e) for e in elems};
            }
        }
        if origin is frozenset {
            try {
                return frozenset(elems);
            } except TypeError {
                return frozenset(str(e) for e in elems);
            }
        }
        if origin is deque {
            return deque(elems);
        }
    }
    if origin is dict {
        key_t = get_args(tp)[0] if get_args(tp) else Any;
        val_t = get_args(tp)[1] if len(get_args(tp)) > 1 else Any;
        def mk_key -> Any {
            k = random_value_for_type(key_t, _depth=_depth + 1, _max_depth=_max_depth);
            try {
                hash(k);
                return k;
            } except TypeError {
                return str(k);
            }
        }
        size = random.randint(0, 5);
        return {
            mk_key(): random_value_for_type(
                val_t, _depth=_depth + 1, _max_depth=_max_depth
            ) for _ in range(size)
        };
    }
    # TypedDict
    if _is_typed_dict(tp) {
        req: set[str] = getattr(tp, '__required_keys__', set());
        opt: set[str] = getattr(tp, '__optional_keys__', set());
        anns = tp.__annotations__;
        out: dict = {};
        for k in req {
            out[k] = random_value_for_type(
                anns[k], _depth=_depth + 1, _max_depth=_max_depth
            );
        }
        for k in opt {
            if random.random() < 0.6 {
                out[k] = random_value_for_type(
                    anns[k], _depth=_depth + 1, _max_depth=_max_depth
                );
            }
        }
        return out;
    }
    # NamedTuple
    if _is_namedtuple(tp) {
        anns = get_type_hints(tp, include_extras=True);
        values = [
            random_value_for_type(anns[name], _depth=_depth + 1, _max_depth=_max_depth)
            for name in tp._fields
        ];
        return tp(*values);
    }
    # Enum
    if _is_enum(tp) {
        return _choose_from(list(tp));
    }
    # Dataclass
    if is_dataclass(tp) {
        try {
            type_hints = get_type_hints(tp, include_extras=True);
        } except Exception {
            type_hints = {};
        }
        kwargs: dict = {};
        for f in dc_fields(tp) {
            if f.init {
                if f.default is not MISSING or f.default_factory is not MISSING {
                    if random.random() < 0.35 {
                        continue;
                    }
                }
                field_type = type_hints.get(f.name, f.type);
                kwargs[f.name] = random_value_for_type(
                    field_type, _depth=_depth + 1, _max_depth=_max_depth
                );
            }
        }
        try {
            assert isinstance(tp, type);
            return tp(**kwargs);
        } except TypeError {
            assert isinstance(tp, type);
            return tp(
                **{
                    k: v
                    for (k, v) in kwargs.items()
                    if v is not MISSING
                }
            );
        }
    }
    # TypeVar: use bound or one of constraints, else Any
    if isinstance(tp, TypeVar) {
        if tp.__constraints__ {
            chosen = _choose_from(tp.__constraints__);
            return random_value_for_type(
                chosen, _depth=_depth + 1, _max_depth=_max_depth
            );
        }
        if tp.__bound__ {
            return random_value_for_type(
                tp.__bound__, _depth=_depth + 1, _max_depth=_max_depth
            );
        }
        return random_value_for_type(Any, _depth=_depth + 1, _max_depth=_max_depth);
    }
    # Callable[...] -> synthesize a dummy callable with compatible signature
    if get_origin(tp) is Callable {
        args = get_args(tp);
        ret_t = Any;
        if args and len(args) == 2 {
            ret_t = args[1];
        }
        def _fn_stub(*_a: Any, **_k: Any) -> Any {
            return random_value_for_type(
                ret_t, _depth=_depth + 1, _max_depth=_max_depth
            );
        }
        return _fn_stub;
    }
    # Plain classes: if it's a built-in container alias, treat as Any
    if tp in (list, set, frozenset, tuple, dict, deque) {
        return random_value_for_type(Any, _depth=_depth + 1, _max_depth=_max_depth);
    }
    # Try to instantiate using __init__ annotations
    if isinstance(tp, type) {
        try {
            sig = inspect.signature(tp);
            kwargs: dict = {};
            for (name, param) in sig.parameters.items() {
                if name == 'self' {
                    continue;
                }
                ann = param.annotation
                if param.annotation is not inspect._empty
                else Any;
                if param.default is not inspect._empty and random.random() < 0.4 {
                    continue;
                }
                if param.kind in (param.VAR_POSITIONAL, param.VAR_KEYWORD) {
                    continue;
                }
                kwargs[name] = random_value_for_type(
                    ann, _depth=_depth + 1, _max_depth=_max_depth
                );
            }
            return tp(**kwargs);
        } except Exception {
            try {
                return tp();
            } except Exception {
                return types.SimpleNamespace();
            }
        }
    }
    # Fallback
    return None;
}

"""Generate a random value for primitive types."""
impl _random_primitive(tp: Any) -> Any {
    if tp is int {
        return random.randint(-(10 ** 6), 10 ** 6);
    }
    if tp is float {
        return random.uniform(-(10 ** 6), 10 ** 6);
    }
    if tp is bool {
        return bool(random.getrandbits(1));
    }
    if tp is str {
        return _rand_str();
    }
    if tp is bytes {
        return _rand_str().encode();
    }
    if tp is complex {
        return complex(random.uniform(-100, 100), random.uniform(-100, 100));
    }
    if tp is Decimal {
        return Decimal(str(random.uniform(-1000, 1000)));
    }
    if tp is UUID {
        return uuid4();
    }
    if tp is datetime {
        return datetime.fromtimestamp(random.randint(0, 2_000_000_000));
    }
    if tp is date {
        return date.fromordinal(random.randint(700_000, 800_000));
    }
    if tp is time {
        return (datetime.min + timedelta(seconds=random.randint(0, 24 * 3600 - 1))).time();
    }
    if tp is type(None) {
        return None;
    }
    return None;
}

"""Choose a random element from a sequence."""
impl _choose_from(seq: Any) -> Any {
    return random.choice(list(seq));
}

"""Unwrap NewType to get the underlying type."""
impl _unwrap_newtype(tp: Any) -> Any {
    if tp?.__supertype__ {
        return tp.__supertype__;
    }
    return tp;
}

"""Unwrap Annotated type to get the underlying type."""
impl _unwrap_annotated(tp: Any) -> Any {
    if get_origin(tp) is Annotated {
        return get_args(tp)[0];
    }
    return tp;
}

"""Safely get subclasses of a type."""
impl _safe_subclasses(tp: Any) -> list[type] {
    try {
        return list(tp.__subclasses__());
    } except Exception {
        return [];
    }
}

"""Check if type is an Enum."""
impl _is_enum(tp: Any) -> bool {
    try {
        import enum;
        return isinstance(tp, type) and issubclass(tp, enum.Enum);
    } except Exception {
        return False;
    }
}

"""Check if type is a NamedTuple."""
impl _is_namedtuple(tp: Any) -> bool {
    return (
        isinstance(tp, type)
        and issubclass(tp, tuple)
        and tp?._fields
        and tp?.__annotations__
    );
}

"""Check if type is a TypedDict."""
impl _is_typed_dict(tp: Any) -> bool {
    return (isinstance(tp, type) and tp?.__annotations__ and tp?.__required_keys__);
}

"""Generate a random string of given length."""
impl _rand_str(n: int = 12) -> str {
    return ''.join(random.choice(_RAND_STR_ALPH) for _ in range(n));
}
