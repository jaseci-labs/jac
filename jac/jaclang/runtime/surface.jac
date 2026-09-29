obj SurfaceEntry {
    has name: str,
        kind: str,
        exposure: str = "private",
        placement: str = "server",
        module: str = "",
        src: str = "",
        explicit_access: bool = True;

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
            "explicit_access": self.explicit_access
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
            explicit_access=bool(rec.get("explicit_access", True))
        );
    }
}
