obj LeftValue {
    has value: int;

    def adjusted -> int {
        return adjust(self.value);
    }
}

def:priv adjust(value: int) -> int {
    return value + 1;
}

def left_adjust(value: int) -> LeftValue {
    return LeftValue(value);
}
