impl AppSpec.effective_route -> str {
    return self.route or f"/api/{self.name}";
}

impl WorkspaceSpec.app(name: str) -> (AppSpec | None) {
    return self.apps.get(name);
}

impl WorkspaceSpec.app_at(real_path: str) -> (AppSpec | None) {
    if not real_path {
        return None;
    }
    for app in self.apps.values() {
        if real_path == app.real_entry {
            return app;
        }
    }
    return None;
}

impl WorkspaceSpec.app_for_path(abs_path: str) -> (AppSpec | None) {
    return self.app_at(normalized_path(abs_path)) if abs_path else None;
}

impl WorkspaceSpec.serving_apps -> list[AppSpec] {
    return [
        a
        for a in self.apps.values()
        if a.has_server
    ];
}
