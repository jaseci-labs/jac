impl BootstrapProjectHost.module_in_flight(names: list[str]) -> str {
    for name in names {
        spec = sys.modules.get(name)?.__spec__;
        if spec is not None and getattr(spec, '_initializing', False) {
            return name;
        }
    }
    return '';
}

impl BootstrapProjectHost.import_in_flight(path: str) -> bool {
    return module_import_in_flight(path);
}
