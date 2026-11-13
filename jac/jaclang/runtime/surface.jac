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

    def is_exposed -> bool;
    def requires_auth -> bool;
    def is_served -> bool;
    def to_dict -> dict[str, any];
    static def from_dict(name: str, rec: dict[str, any]) -> SurfaceEntry;
}
