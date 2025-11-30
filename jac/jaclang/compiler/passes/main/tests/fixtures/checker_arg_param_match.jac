class Foo {
    def bar(self: Foo, a: int) -> None { }
    static def baz(self: int, a: int) -> None { }
}

def foo(
    a: int, b: int, /, c: int, d: int, *args: int, e: int, f: int, **kwargs: int
) -> None { }

def bar(a: int, b: int, /, c: int, d: int, e: int, f: int) -> None { }
def baz(a: int, *, b: int) -> None { }

with entry {
    f = Foo();

    f.bar();
    f.bar(1);
    f.bar(1, 2);

    f.baz();
    f.baz(1);
    f.baz(1, 2);

    foo(1, 2, 3, d=4, e=5, f=6, g=7, h=8);  # c is positional and d is named
    foo(1, 2, 3, 4, 5, 6, 7, 8, e=5, f=6);  # marching extra with *args
    foo(1, 2, d=3, e=4, f=5, c=4);  # order does not matter for named

    foo(1, 2, 3, d=4, e=5, g=7, h=8);  # missing argument 'f'
    foo(1, b=2, c=3, d=4, e=5, f=6);  # b is positional only

    bar(1, 2, 3, 4, 5, f=6);
    bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
    bar(1, 2, 3, 4, 5, 6, c=3);  # already matched
    bar(1, 2, 3, 4, 5, 6, h=1);  # h is not matched

    baz(a=1, b=2);
    baz(1, b=2);  # a can be both positional and keyword
    baz(1, 2);  # 'b' can only be keyword arg
}
