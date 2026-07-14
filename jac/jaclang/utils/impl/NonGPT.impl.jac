impl random_value_for_type(tp: any, *, _depth: int = 0, _max_depth: int = 10) -> any {
    random.seed(42);
    if _depth > _max_depth {
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

    if tp in (Any, object) {
        return random.choice(
            [_rand_str(), random.randint(0, 9999), True, None, random.uniform(0, 1)]
        );
    }

    prim = _random_primitive(tp);
    if prim is not None {
        return prim;
    }

    if get_origin(tp) is Literal {
        choices = get_args(tp);
        return _choose_from(choices);
    }

    if get_origin(tp) is Union {
        options = list(get_args(tp));

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

    if get_origin(tp) is tuple {
        args = get_args(tp);
        if len(args) == 2 and args[1] is Ellipsis {
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
        def mk_key -> any {
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

    if _is_namedtuple(tp) {
        anns = get_type_hints(tp, include_extras=True);
        values = [
            random_value_for_type(anns[name], _depth=_depth + 1, _max_depth=_max_depth)
            for name in tp._fields
        ];
        return tp(*values);
    }

    if _is_enum(tp) {
        return _choose_from(list(tp));
    }

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

    if get_origin(tp) is Callable {
        args = get_args(tp);
        ret_t = Any;
        if args and len(args) == 2 {
            ret_t = args[1];
        }
        def _fn_stub(*_a: any, **_k: any) -> any {
            return random_value_for_type(
                ret_t, _depth=_depth + 1, _max_depth=_max_depth
            );
        }
        return _fn_stub;
    }

    if tp in (list, set, frozenset, tuple, dict, deque) {
        return random_value_for_type(Any, _depth=_depth + 1, _max_depth=_max_depth);
    }

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

    return None;
}

impl _random_primitive(tp: any) -> any {
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
        return (
            datetime.min + timedelta(seconds=random.randint(0, 24 * 3600 - 1))
        ).time();
    }
    if tp is type(None) {
        return None;
    }
    return None;
}

impl _choose_from(seq: any) -> any {
    return random.choice(list(seq));
}

impl _unwrap_newtype(tp: any) -> any {
    if tp?.__supertype__ {
        return tp.__supertype__;
    }
    return tp;
}

impl _unwrap_annotated(tp: any) -> any {
    if get_origin(tp) is Annotated {
        return get_args(tp)[0];
    }
    return tp;
}

impl _is_enum(tp: any) -> bool {
    try {
        import enum;
        return isinstance(tp, type) and issubclass(tp, enum.Enum);
    } except Exception {
        return False;
    }
}

impl _is_namedtuple(tp: any) -> bool {
    return (
        isinstance(tp, type)
        and issubclass(tp, tuple)
        and tp?._fields
        and tp?.__annotations__
    );
}

impl _is_typed_dict(tp: any) -> bool {
    return (isinstance(tp, type) and tp?.__annotations__ and tp?.__required_keys__);
}

impl _rand_str(n: int = 12) -> str {
    return ''.join(random.choice(_RAND_STR_ALPH) for _ in range(n));
}
