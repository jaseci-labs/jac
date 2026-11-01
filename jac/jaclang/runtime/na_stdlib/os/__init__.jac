import from collections.abc { Callable, Iterator }

obj _WalkFrame {
    has top: str,
        dirs: list[str] = [],
        files: list[str] = [];
}

obj _Walker {
    has topdown: bool = True,
        onerror: (Callable[[OSError], None] | None) = None,
        followlinks: bool = False,
        pending: list[str] = [],
        emitted: (_WalkFrame | None) = None,
        links: set[str] = set();

    def __iter__ -> _Walker;
    def __next__ -> tuple[str, list[str], list[str]];
    def scan(top: str) -> (_WalkFrame | None);
    def descend_from(frame: _WalkFrame);
}

def _walk_bottom_up(
    top: str,
    onerror: (Callable[[OSError], None] | None),
    followlinks: bool,
    out: list[tuple[str, list[str], list[str]]]
);

def:pub walk(
    top: str,
    topdown: bool = True,
    onerror: (Callable[[OSError], None] | None) = None,
    followlinks: bool = False
) -> Iterator[tuple[str, list[str], list[str]]];
