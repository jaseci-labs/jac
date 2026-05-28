import from dataclasses { dataclass }

def test_func() -> None {
    '''docstring for MyResult'''
    obj MyResult {
        has value: str = "";
    }

    '''docstring for local func'''
    def helper() -> str {
        return "hi";
    }

    '''docstring for decorated class'''
    @dataclass
    class Config {
        with entry {
            debug: bool = False;
        }
    }
}

obj MyResult {
    '''docstring for with entry'''
    with entry {
        has value: str = "";
    }
}
