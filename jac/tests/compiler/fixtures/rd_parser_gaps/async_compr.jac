"""Test async comprehension parsing."""

def demo_async_compr -> None {
    results = [item async for item in aiter()];
    unique = {item async for item in aiter()};
    total = (item async for item in aiter());
    filtered = [x async for x in aiter() if x > 0];
}
