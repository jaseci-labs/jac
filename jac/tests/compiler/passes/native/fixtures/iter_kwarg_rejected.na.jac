# `iter`/`next` are positional-only (CPython rejects keyword args). The native
# checker must reject the keyword form rather than typing a call the backend
# cannot lower. (#6403)
def kw_next() -> int {
    it = iter([5, 7, 9]);
    return next(it=it);
}
