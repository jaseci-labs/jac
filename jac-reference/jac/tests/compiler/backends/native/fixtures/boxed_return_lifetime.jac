obj Item {
    has value: int;
}

def forward(items: list[Item]) -> (list[Item] | Item) {
    return items;
}

obj Source {
    has body: (list[Item] | Item) {
        getter {
            return forward([Item(2), Item(3), Item(5)]);
        }
    }
}

def probe -> int {
    source = Source();
    total = 0;
    if isinstance(source.body, list) {
        for item in source.body {
            total += item.value;
        }
    }
    return total;
}

with entry {
    assert probe() == 10;
}
