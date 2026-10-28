impl starts_at_earliest(start_from: any) -> bool {
    token = start_from.value if isinstance(start_from, StreamPosition) else start_from;
    return token == StreamPosition.EARLIEST.value;
}

impl _method_params(fn: any) -> list[MethodParam] {
    import inspect;
    params: list[MethodParam] = [];
    for p in inspect.signature(fn).parameters.values() {
        if p.name == 'self' {
            continue;
        }
        params.append(
            MethodParam(
                name=p.name,
                kind=p.kind.name,
                has_default=(p.`default is not inspect.Parameter.empty),
                `default=(None if p.`default is inspect.Parameter.empty else p.`default)
            )
        );
    }
    return params;
}

impl _signature_faults(
    method: str, want: list[MethodParam], got: list[MethodParam]
) -> list[str] {
    faults: list[str] = [];
    provided: dict[str, MethodParam] = {p.name: p for p in got};
    absorbs = any(p.kind in _VARIADIC_KINDS for p in got);
    declared = [p.name for p in want];
    for w in want {
        have = provided.get(w.name);
        if have is None {
            if not absorbs {
                faults.append(f"{method} drops parameter '{w.name}'");
            }
            continue;
        }
        if have.kind == 'POSITIONAL_ONLY' and w.kind != 'POSITIONAL_ONLY' {
            faults.append(f"{method} makes '{w.name}' positional-only");
        }
        if w.has_default and not have.has_default {
            faults.append(f"{method} drops the default {w.`default} for '{w.name}'");
        } elif w.has_default and have.`default != w.`default {
            faults.append(
                f"{method} defaults '{w.name}' to {have.`default}, "
                f"interface declares {w.`default}"
            );
        }
    }
    ordered = [
        p.name
        for p in got
        if p.kind in _POSITIONAL_KINDS and p.name in declared
    ];
    expected = [
        name
        for name in declared
        if name in ordered
    ];
    if ordered != expected {
        faults.append(f"{method} orders parameters {ordered}, expected {expected}");
    }
    for p in got {
        if (
            (p.kind not in _VARIADIC_KINDS)
            and (p.name not in declared)
            and not p.has_default
        ) {
            faults.append(f"{method} adds required parameter '{p.name}'");
        }
    }
    return faults;
}

impl _assert_signature_parity(broker_cls: type) {
    faults: list[str] = [];
    for (name, declared) in vars(EventStreamBroker).items() {
        if name.startswith('_') or not callable(declared) {
            continue;
        }
        supplied = getattr(broker_cls, name, None);
        if supplied is declared {
            continue;
        }
        if not callable(supplied) {
            faults.append(f"{name} is not a method");
            continue;
        }
        faults.extend(
            _signature_faults(name, _method_params(declared), _method_params(supplied))
        );
    }
    if faults {
        detail = '; '.join(faults);
        raise TypeError(
            f"{broker_cls.__module__}.{broker_cls.__name__} diverges from the "
            f"EventStreamBroker interface: {detail}"
        );
    }
}

impl EventStreamBroker.__init_subclass__(**kwargs: object) {
    super.__init_subclass__(**kwargs);
    _assert_signature_parity(cast(type, cls));
}
