obj Binding {
    has name: str,
        source_module: str;
}

with entry {
    bindings = [Binding(name="foo", source_module="m1")];
    binding = None;
    for b in bindings {
        if b.name == "foo" {
            binding = b;  # <-- Ok
            break;
        }
    }
    picked = None;
    picked = 42;  # <-- Ok
    typed_binding: Binding | None = None;
    typed_binding = bindings[0];  # <-- Ok
    typed_binding = 99;  # <-- Error
    strict: None = None;
    strict = 7;  # <-- Error
    count = 0;
    count = "bad";  # <-- Ok (unannotated widens)(same as pyright)
}
