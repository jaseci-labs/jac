"""`inspect.getfile` accepts a union ending in `Callable[..., Any]`."""

import from inspect { getfile }


def test_fixture_call(test_fun: Callable) -> str {
    return getfile(test_fun);
}


def test_fixture_class(cls: type) -> str {
    return getfile(cls);
}
