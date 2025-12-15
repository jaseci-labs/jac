def foo(param: int, **kwargs: dict) -> int {
    return (param + kwargs['bar'], 'from_foo');
}

with entry {
    mydict = {'new_val': 1, 'where': 0};
    (mydict['new_val'], mydict['where']) = foo(1, bar=2);
    print(f"<link href='{mydict}' rel='stylesheet'>");
    print(1 != 2);
}
