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
    count = "bad";  # <-- Error (unannotated var frozen to int at first bind)
}

obj Sku {
    has id: str = "",
        productId: str = "";
}

# A name first bound to None reads as the union of its bindings, so the
# `is not None` guard narrows it to the object type.
def find_product(skus: list[Sku], wanted: str) -> str | None {
    sku = None;
    for candidate in skus {
        if candidate.id == wanted {
            sku = candidate;
            break;
        }
    }
    return sku.productId if sku is not None else None;  # <-- Ok
}

# A binding inside an unpacking target counts as one of the name's bindings.
def unpack_rebind(pair: tuple[Sku, int]) -> str {
    item = None;
    (item, count) = pair;
    return item.productId if item is not None else "";  # <-- Ok
}

# A rebinding that reads the name itself adds `int`, not an Unknown.
def self_reference -> str {
    value = None;
    value = value or 1;
    wrong: str = value if value is not None else "";  # <-- Error
    return wrong;
}
