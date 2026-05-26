import from jir_has_assign_module { Container }

with entry {
    c = Container();
    c.value = 42;
    c.name = "hello";
    c.items = [1, 2, 3];
}
