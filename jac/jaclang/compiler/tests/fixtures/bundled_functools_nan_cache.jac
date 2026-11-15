"""NaN arguments to native lru_cache must miss instead of aliasing by text."""

import from functools { lru_cache }


def ftn_identity(x: any) -> any {
    return x;
}


def nan_cache_counts -> int {
    cached = lru_cache(maxsize=4).__call__(ftn_identity);
    first: float = float("nan");
    second: float = float("nan");
    cached.__call__(first);
    cached.__call__(first);
    cached.__call__(second);
    info = cached.cache_info();
    return info.hits * 100 + info.misses * 10 + info.currsize;
}
