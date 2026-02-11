"""Test async for loop parsing."""

def demo_async_for -> None {
    async for item in aiter() {
        print(item);
    }
    async for item in aiter() {
        print(item);
    } else {
        print("empty");
    }
}
