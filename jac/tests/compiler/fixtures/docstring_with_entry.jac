obj MyResult {
    '''docstring for has'''
    has value: str = "";

    '''docstring for def'''
    def get_value() -> str {
        return self.value;
    }

    '''docstring for with entry'''
    with entry {}

    '''docstring for nested obj'''
    obj Inner {
        has x: int = 0;
    }
}
