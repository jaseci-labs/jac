obj _CacheInfo {
    has hits: int,
        misses: int,
        maxsize: any,
        currsize: int;
}


obj:pub partial {
    has func: Callable[[any, any], any],
        args: list[any],
        keywords: dict[str, any];

    def init(fn: Callable[[any, any], any], bound: any);
    def __call__(x: any) -> any;
}


obj _KeyWrapper {
    has cmp: Callable[[any, any], any],
        `obj: any;

    def _cmpv(other: _KeyWrapper) -> float;
    def __lt__(other: _KeyWrapper) -> bool;
    def __gt__(other: _KeyWrapper) -> bool;
    def __le__(other: _KeyWrapper) -> bool;
    def __ge__(other: _KeyWrapper) -> bool;
    def __eq__(other: _KeyWrapper) -> bool;
    def __ne__(other: _KeyWrapper) -> bool;
}


obj _KeyFactory {
    has cmp: Callable[[any, any], any];

    def __call__(val: any) -> _KeyWrapper;
}


obj _lru_cache_wrapper {
    has fn: Callable[[any], any],
        cap: (int | None),
        typed: bool,
        store_i: dict[int, int],
        store_s: dict[str, int],
        vals: list[any],
        key_i: list[int],
        key_s: list[str],
        is_i: list[bool],
        prev: list[int],
        nxt: list[int],
        head: int = -1,
        tail: int = -1,
        hits: int = 0,
        misses: int = 0;

    def _unlink(slot: int);
    def _push(slot: int);
    def _hit(slot: int) -> any;
    def _miss(x: any, ik: int, use_i: bool, sk: str) -> any;
    def __call__(x: any) -> any;
    def cache_info -> _CacheInfo;
    def cache_parameters -> dict[str, any];
    def cache_clear;
}


obj _LruDeco {
    has cap: (int | None),
        typed: bool = False;

    def __call__(fn: Callable[[any], any]) -> _lru_cache_wrapper;
}


obj _WrapDeco {
    has wrapped: any;

    def __call__(wrapper: Callable[[any], any]) -> Callable[[any], any];
}


obj _NoInitial {}


glob _NO_INITIAL: _NoInitial = _NoInitial();


def:pub reduce(
    function: Callable[[any, any], any], iterable: list[any], initial: any = _NO_INITIAL
) -> any;


def:pub cmp_to_key(mycmp: Callable[[any, any], any]) -> _KeyFactory;


def:pub lru_cache(maxsize: (int | None) = 128, typed: bool = False) -> _LruDeco;


def:pub cache(fn: Callable[[any], any]) -> _lru_cache_wrapper;


glob WRAPPER_ASSIGNMENTS: list[str] = [
         "__module__",
         "__name__",
         "__qualname__",
         "__doc__",
         "__annotate__",
         "__type_params__"
     ],
     WRAPPER_UPDATES: list[str] = ["__dict__"];


def:pub update_wrapper(
    wrapper: Callable[[any], any],
    wrapped: any,
    assigned: any = None,
    updated: any = None
) -> Callable[[any], any];


def:pub wraps(wrapped: any, assigned: any = None, updated: any = None) -> _WrapDeco;
