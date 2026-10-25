import sys;


obj Inverse {
    has fn: Callable,
        args: list[any] = [],
        keys: list[str] = [];

    def run;
}


obj Fiber {
    has name: str,
        inject: list[str] = [],
        provide: list[str] = [],
        apply: Callable | None = None,
        active: bool = False,
        parent: str = "root";

    def satisfied(ctx: EffectContext) -> bool;
}


obj EffectContext {
    has store: dict[str, object] = {},
        registry: dict[str, Fiber] = {},
        frames: dict[str, list[Inverse]] = {},
        root_frame: list[Inverse] = [],
        current_fiber: str = "",
        verbose: bool = False;

    def has_key(key: str) -> bool;
    def get(key: str) -> object;
    def _log(msg: str);
    def set(key: str, value: object);
    def unset(key: str);
    def _record(inv: Inverse);
    def effect(
        fn: Callable,
        args: list[any],
        inverse: Callable,
        inv_args: list[any],
        keys: list[str] = []
    );

    def use(comp: Fiber) -> str;
    def unload(name: str) -> None;
    def swap(old_name: str, comp: Fiber) -> str;
    def _recover_frame(name: str);
    def _refresh;
    def _activate(name: str) -> None;
    def _notify(keys: list[str]) -> None;
    def dispose_all;
}
