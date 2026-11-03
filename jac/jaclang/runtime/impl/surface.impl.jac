impl SurfaceEntry.is_exposed -> bool {
    return self.exposure != "private";
}

impl SurfaceEntry.requires_auth -> bool {
    return self.exposure != "public";
}

impl SurfaceEntry.is_served -> bool {
    return self.is_exposed() and self.placement != "client";
}

impl SurfaceEntry.to_dict -> dict[str, any] {
    return {
        "kind": self.kind,
        "exposure": self.exposure,
        "placement": self.placement,
        "module": self.module,
        "src": self.src,
        "explicit_access": self.explicit_access,
        "route": self.route,
        "scheduled": self.scheduled,
        "reflect": self.reflect
    };
}

impl SurfaceEntry.from_dict(name: str, rec: dict[str, any]) -> SurfaceEntry {
    route: (dict[str, any] | None) = None;
    declared = rec.get("route");
    if isinstance(declared, dict) {
        table: dict[str, any] = declared;
        route = {key: table[key] for key in table};
    }
    return SurfaceEntry(
        name=str(name),
        kind=str(rec.get("kind") or ""),
        exposure=str(rec.get("exposure") or "private"),
        placement=str(rec.get("placement") or "server"),
        module=str(rec.get("module") or ""),
        src=str(rec.get("src") or ""),
        explicit_access=bool(rec.get("explicit_access", True)),
        route=route,
        scheduled=bool(rec.get("scheduled", False)),
        reflect=bool(rec.get("reflect", "route" not in rec))
    );
}
