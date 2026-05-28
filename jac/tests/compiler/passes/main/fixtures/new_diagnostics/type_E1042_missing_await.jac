"""Fixture for E1042: calling an async function without `await`.

An `async def` call evaluates to a coroutine (`Coroutine[Any, Any, T]`),
not `T`. Assigning that coroutine where the unwrapped value is expected is
a missing-`await` bug that crashes at runtime. The awaited forms below must
type-check cleanly; the un-awaited forms must raise E1042.
"""

async def get_num -> int {
    return 5;
}

async def get_nums -> list[int] {
    return [1, 2, 3];
}

async def main_async -> None {
    bad_num: int = get_num();              # E1042: coroutine, missing await
    ok_num: int = await get_num();         # ok

    bad_list: list[int] = get_nums();      # E1042: coroutine, missing await
    ok_list: list[int] = await get_nums(); # ok
}
