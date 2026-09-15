def identity(cls: type) -> type {
    return cls;
}

def test_func {
    '''docstring for MyResult'''
    obj MyResult {
        has value: str = "";
    }

    '''docstring for local func'''
    def helper -> str {
        return "hi";
    }

    '''docstring for local object'''
    @identity
    obj Config {
        has debug: bool = False;
    }
}

obj MyResult {
    '''docstring for with entry'''
    with entry {
        has value: str = "";
    }
}
