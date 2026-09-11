"""The empty tuple names its arguments by writing an empty argument list."""

obj Stage {
    static has PROVIDES: tuple[()] = (),
        REQUIRES: tuple[str] = ('x', );
}


glob NOTHING: tuple[()] = ();


def bare_still_errors(rows: dict[str, tuple]) -> int {
    return len(rows);
}
