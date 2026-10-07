"""Method calls on `any` receivers next to their concretely typed twins."""

glob OP: int = 8;

obj AnyBox {
    has items: any = None;
}

obj TypedBox {
    has items: list[int] = [],
        code: bytearray = bytearray();
}


def any_field_append -> int {
    box = AnyBox();
    box.items = [];
    box.items.append(OP);
    l: list[int] = box.items;
    return len(l);
}


def any_field_bytearray_append -> int {
    box = AnyBox();
    box.items = bytearray();
    box.items.append(OP);
    box.items.append(3);
    b: bytearray = box.items;
    return len(b);
}


def any_param_count(items: any) -> int {
    return items.count(1);
}


def typed_field_append -> int {
    box = TypedBox();
    box.items.append(OP);
    box.items.append(OP);
    box.code.append(OP);
    return len(box.items) * 10 + len(box.code);
}


def file_param_read(fp: File) -> int {
    return len(fp.read());
}
