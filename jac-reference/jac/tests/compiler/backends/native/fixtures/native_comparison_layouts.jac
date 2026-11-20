def tuple_parameter(pair: tuple[int, int], seed: int) -> bool {
    return pair == (seed, seed + 1)
        and (seed, seed + 1) == pair
        and pair != (seed + 1, seed)
        and pair < (seed + 1, seed)
        and (seed + 1, seed) > pair;
}

def comparison_layouts(seed: int) -> bool {
    pair: tuple[int, int] = (seed, seed + 1);
    other: tuple[int, int] = (seed + 1, seed);
    small: set[int] = {seed};
    large: set[int] = {seed, seed + 1};
    return tuple_parameter(pair, seed)
        and pair != other
        and pair < other
        and small < large
        and large > small
        and small != large
        and small == {seed};
}

def optional_arithmetic(value: int | None) -> int {
    if value is None {
        return 0;
    }
    return value + 1;
}

def optional_values(seed: int) -> bool {
    return optional_arithmetic(None) == 0 and optional_arithmetic(seed) == seed + 1;
}
