glob unidata_version: str = UNIDATA_VERSION,
     _cat_starts: list[int] = [],
     _cat_values: list[int] = [],
     _width_starts: list[int] = [],
     _width_values: list[int] = [];


def _load_runs(data: str, starts: list[int], values: list[int]) -> None;


def _lookup(cp: int, starts: list[int], values: list[int]) -> int;


def:pub category(ch: str) -> str;


def:pub east_asian_width(ch: str) -> str;
