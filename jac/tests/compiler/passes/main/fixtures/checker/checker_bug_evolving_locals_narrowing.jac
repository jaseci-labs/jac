"""Bug #EVOLVING-NONE: `x = None` then reassigning in an `if` branch
was not narrowed properly post-branch.

"""

def get_cache() -> set[str] {
    cache = None;
    if cache is None {
        cache = set();
    }
    return cache;
}
