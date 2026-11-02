import ctypes;


test "native lru_cache does not merge NaN arguments by string form" {
    import from jaclang.compiler.tests.xbackend_equiv { compile_native, get_func }
    (eng, _) = compile_native("bundled_functools_nan_cache.jac");
    stats = get_func(eng, "nan_cache_counts", ctypes.c_int64)();
    assert stats == 30 , (
        "two calls with one NaN and one call with another must be three misses "
        f"and no stored entries: encoded cache_info={stats}"
    );
}
