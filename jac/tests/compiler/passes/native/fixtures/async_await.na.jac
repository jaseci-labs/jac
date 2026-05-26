"""Native fixture exercising async/await.

Native has no event loop, so an `async def` compiles like a normal
function and `await e` resolves immediately to the value of `e` (every
awaited coroutine has, in this synchronous model, already run). This is
correct for sequential async code; it does not provide concurrency.
"""

async def get_val() -> int {
    return 5;
}

async def add_async(a: int, b: int) -> int {
    return a + b;
}

async def driver(n: int) -> int {
    x = await get_val();
    y = await add_async(x, n);
    return y;
}

async def nested_await(n: int) -> int {
    return await add_async(await get_val(), n);
}
