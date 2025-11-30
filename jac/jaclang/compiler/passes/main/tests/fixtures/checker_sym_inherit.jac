node Parent {
    has val: int = 42;
}

node Child(Parent) {}

with entry {
    c = Child();
    c.val = 42;  # <-- Ok
    c.val = "str";  # <-- Error
}
