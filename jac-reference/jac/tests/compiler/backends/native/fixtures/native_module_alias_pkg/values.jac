obj AliasedValue {
    has value: int = 17;
}

def alias_value(value: int) -> int {
    return value + 3;
}

glob ALIAS_COUNT: int = 5;

def make_alias_value(value: int = 17) -> AliasedValue {
    return AliasedValue(value);
}
