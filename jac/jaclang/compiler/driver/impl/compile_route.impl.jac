impl install_compile_route(route: CompileRoute) {
    _ROUTES.clear();
    _ROUTES.append(route);
}

impl installed_compile_route -> (CompileRoute | None) {
    return _ROUTES[0] if _ROUTES else None;
}
