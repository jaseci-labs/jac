"""Test async with statement parsing."""

def demo_async_with -> None {
    async with open("file.txt") as fh {
        data = fh.read();
        print(data);
    }
    async with open("a.txt") as a, open("b.txt") as b {
        print(a.read(), b.read());
    }
}
