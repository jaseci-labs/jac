impl _marks -> set[str] {
    marked = handoff().get("building");
    if isinstance(marked, list) {
        return {str(name) for name in marked};
    }
    return set();
}

impl _record(marked: set[str]) {
    update_handoff(building=sorted(marked) or None);
}

impl building -> frozenset[str] {
    return frozenset(_marks());
}

impl begin(names: list[str]) -> list[str] {
    marked = _marks();
    added = [
        name
        for name in names
        if name not in marked
    ];
    _record(marked | set(added));
    return added;
}

impl end(names: list[str]) {
    _record(_marks() - set(names));
}

impl resolution_in_flight -> bool {
    names = set(ROUTER_MODULES);
    for target in ARTIFACTS.values() {
        names.add(target.split(":", 1)[0]);
    }
    for name in names {
        module = sys.modules.get(name);
        spec = module?.__spec__ if module is not None else None;
        if spec is not None and getattr(spec, "_initializing", False) {
            return True;
        }
    }
    return False;
}
