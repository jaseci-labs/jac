"""A caller-owned string must outlive borrows without accumulating references."""

obj Text {
    has value: str;

    def length(other: str) -> int {
        return len(other);
    }

    def tail -> str {
        view = self.value[1:];
        return view;
    }
}

obj TextList {
    has values: list[str] = [];

    def init(values: list[str]) {
        self.values = values;
    }
}

def local(value: str) -> int {
    copy = value;
    return len(copy);
}

def field(value: str) -> int {
    text = Text(value=value);
    return len(text.value);
}

def loop(value: str) -> int {
    count = 0;
    for i in range(3) {
        copy = value;
        count += len(copy);
    }
    return count;
}

def identity(value: str) -> str {
    return value;
}

def call(value: str) -> int {
    return len(identity(value));
}

def constructor_call(value: str) -> int {
    text = Text(value=identity(value));
    return len(text.value);
}

def constructor_list(value: str) -> int {
    texts = TextList(values=[value]);
    return len(texts.values[0]);
}

def sliced(value: str) -> int {
    tail = value[1:];
    return len(tail) + 1;
}

def rebound(value: str) -> int {
    value = value[1:];
    return len(value) + 1;
}

def temporary_index(value: str) -> int {
    return len([value][0]);
}

def temporary_condition(value: str) -> int {
    if [value] {
        return len(value);
    }
    return 0;
}

def discarded(value: str) -> int {
    identity(value);
    return len(value);
}

def compared(value: str) -> int {
    return len(value) if identity(value) == value else 0;
}

def class_call(value: str) -> int {
    return Text.length(Text(value=value), identity(value));
}

def view_field(value: str) -> int {
    text = Text(value=value[1:-1]);
    return len(text.value) + 2;
}

def borrowed_view_field(value: str) -> int {
    view = value[1:-1];
    text = Text(value=view);
    return len(text.value) + 2;
}

def compared_view(value: str) -> int {
    return len(value) if value[:3] == "bor" else 0;
}

def mixed_condition(value: str) -> int {
    if [value] or False {
        return len(value);
    }
    return 0;
}

def conditional_owned(value: str) -> int {
    return len(identity(value) if len(value) > 0 else value);
}

def conditional_borrowed(value: str) -> int {
    return len(identity(value) if len(value) == 0 else value);
}

def returned_view(value: str) -> int {
    return len(Text(value=value).tail()) + 1;
}

def dict_read(value: str) -> int {
    values = {value: len(value)};
    return values[value];
}

def dict_write(value: str) -> int {
    values: dict[str, str] = {};
    values[value] = value;
    return len(values) * len(value);
}

def dict_missing(value: str) -> int {
    values: dict[str, int] = {};
    try {
        return values[value];
    } except KeyError {
        return len(value);
    }
}

node Item {}

def descendants(item: Item) -> list[Item] {
    return [item-->];
}

def empty_items -> list[Item] {
    return [];
}

def identity_items(items: list[Item]) -> list[Item] {
    return items;
}

def destroy_items(items: list[Item]) {
    del identity_items(items);
}
