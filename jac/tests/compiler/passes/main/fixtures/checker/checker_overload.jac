import from typing { Any, overload }

obj Foo {
    @overload
    def do_something(value: int) -> str {}

    @overload
    def do_something(value: list[int]) -> str {}

    @overload
    def __add__(other: int) -> bool {}

    @overload
    def __add__(other: list[int]) -> bool {}
}

with entry {
    # @overload
    # def __pow__(self, value: int, mod: None = None, /) -> float: ...
    #
    # return type must be Any as `float | complex` causes too many false-positive errors
    # @overload
    # def __pow__(self, value: float, mod: None = None, /) -> Any: ...
    x: float = 3.14 ** 42;  # <-- Ok
    y: Any = 3.14 ** 2.71;  # <-- Ok

    foo: Foo = Foo();
    foo.do_something(10);  # <-- Ok
    foo.do_something([1, 2, 3]);  # <-- Ok
    foo.do_something("hello");  # <-- Error

    foo + 42;  # <-- Ok
    foo + [1, 2, 3];  # <-- Ok
    foo + "hello";  # <-- Error
}
