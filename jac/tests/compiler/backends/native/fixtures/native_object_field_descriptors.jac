"""Regression coverage for native lowering of internal object descriptors."""
import from jaclang.runtime.object_model { ObjectField }

glob calls: int = 0;

def make_value(seed: int = 7) -> int {
    calls += 1;
    return seed;
}

def make_items -> list[int] {
    return [3, 5];
}

obj Record {
    has hidden: int = ObjectField(default_factory=make_value, `init=False),
        value: int = ObjectField(default_factory=make_value),
        keyword: int = ObjectField(`default=13, kw_only=True),
        items: list[int] = ObjectField(default_factory=make_items),
        empty: list[int] = ObjectField(default_factory=`list);
}

def probe -> bool {
    before = calls;
    first = Record();
    second = Record(value=11);
    third = Record(21, keyword=33);
    fourth = Record(31, items=[8]);
    first.items.append(9);
    first.empty.append(2);
    return calls == before + 5
        and first.value == 7
        and first.hidden == 7
        and second.value == 11
        and second.hidden == 7
        and second.keyword == 13
        and third.value == 21
        and third.hidden == 7
        and third.keyword == 33
        and fourth.value == 31
        and fourth.keyword == 13
        and fourth.items[0] == 8
        and len(first.items) == 3
        and len(second.items) == 2
        and len(second.empty) == 0;
}

with entry {
    assert probe();
}
