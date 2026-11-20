import os;


obj PlacementWork {
    has modules: dict[int, uni.Module] = {},
        edges: dict[int, tuple[uni.Import, uni.Module]] = {},
        owned: dict[int, list[int]] = {},
        readers: dict[int, dict[int, bool]] = {},
        path_readers: dict[str, dict[int, bool]] = {},
        reads: dict[int, set[int]] = {},
        paths: dict[int, set[str]] = {},
        references: dict[int, dict[int, set[int]]] = {},
        pending: set[int] = set(),
        queue: list[int] = [],
        cursor: int = 0,
        current: int | None = None,
        solving: bool = False,
        seeded: set[int] = set();

    def enqueue(edge_id: int);
    def track(module: uni.Module);
    def refresh(module: uni.Module);
    def changed(module: uni.Module);
    def forget(module: uni.Module);
    def forget_path(path: str);
    def observe(module: uni.Module);
    def observe_path(path: str);
    def unwatch(eid: int);
    def refs(module: uni.Module) -> dict[int, set[int]];
    def drain(prog: JacProgram);
}
