node Bar {}

node Foo {
    def __call__()  -> Bar {
        return Bar();
    }
}

def fn()  -> Foo {
    return Foo();
}

with entry {
    b: Bar = fn()();  # <-- Ok
    f: Foo = fn()();  # <-- Error
}
