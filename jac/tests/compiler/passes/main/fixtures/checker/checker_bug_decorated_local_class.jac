import from dataclasses { dataclass }

def test_local_dataclass() -> None {
    @dataclass
    class MyResult {
        with entry {
            is_match: bool = False;
            value: (str | None) = None;
        }
    }

    result = MyResult();
    x: bool = result.is_match;
    y: (str | None) = result.value;
}
