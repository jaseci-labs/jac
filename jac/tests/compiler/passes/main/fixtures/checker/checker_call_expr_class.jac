node Foo {
    has i: int = 0;
}

with entry {
    cls = Foo;
    inst = cls();  # <-- Call expression target of class type

    inst.i = 42;  # <-- Ok
    inst.i = 'str';  # <-- Error
}
