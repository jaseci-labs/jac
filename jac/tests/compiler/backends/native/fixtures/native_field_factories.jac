glob calls: int = 0;

def make_value(seed: int = 7) -> int {
    calls += 1;
    return seed;
}

def make_items -> list[int] {
    return [3, 5];
}

obj Record {
    has hidden: int postinit,
        value: int = make_value(),
        keyword: int = 13,
        items: list[int] = make_items(),
        empty: list[int] = [];

    def postinit {
        self.hidden = make_value();
    }
}

def probe -> bool {
    before = calls;
    first = Record();
    second = Record(value=11);
    third = Record(21, keyword=33);
    first.items.append(9);
    first.empty.append(2);
    return calls == before + 4
        and first.value == 7
        and first.hidden == 7
        and second.value == 11
        and second.hidden == 7
        and second.keyword == 13
        and third.value == 21
        and third.hidden == 7
        and third.keyword == 33
        and len(first.items) == 3
        and len(second.items) == 2
        and len(second.empty) == 0;
}

with entry {
    assert probe();
}
