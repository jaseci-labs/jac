obj Foo {}
obj Bar {}

with entry {
    fb: Foo | Bar = Foo();
    fb = Bar();  # <-- Ok
    fb = 42;  # <-- Error

    a: int | float = 1;
    a = 2.5;  # <-- Ok
    a = False;  # <-- Ok Bool is subtype of int (for some reason).
    a = "";  # <-- Error
    a = Foo();  # <-- Error
}
