obj SurfaceEntry {
    has name: str,
        kind: str,
        exposure: str = "private",
        placement: str = "server",
        module: str = "",
        src: str = "",
        explicit_access: bool = True,
        route: (dict[str, any] | None) = None,
        scheduled: bool = False,
        reflect: bool = False;

    def is_exposed -> bool {
        return self.exposure != "private";
    }

    def requires_auth -> bool {
        return self.exposure != "public";
    }

    def is_served -> bool {
        return self.is_exposed() and self.placement != "client";
    }

    def to_dict -> dict[str, any] {
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

    static def from_dict(name: str, rec: dict[str, any]) -> SurfaceEntry {
        return SurfaceEntry(
            name=str(name),
            kind=str(rec.get("kind") or ""),
            exposure=str(rec.get("exposure") or "private"),
            placement=str(rec.get("placement") or "server"),
            module=str(rec.get("module") or ""),
            src=str(rec.get("src") or ""),
            explicit_access=bool(rec.get("explicit_access", True)),
            route=dict(rec["route"]) if isinstance(rec.get("route"), dict) else None,
            scheduled=bool(rec.get("scheduled", False)),
            reflect=bool(rec.get("reflect", "route" not in rec))
        );
    }
}
