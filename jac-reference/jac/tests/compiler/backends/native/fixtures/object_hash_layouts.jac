obj First { has value: int = 3; }
obj Second { has value: int = 7; }

def probe -> int {
    words: set[str] = {"one", "two"};
    first = First();
    equal_fields = First();
    second = Second();
    firsts: set[First] = {first, equal_fields};
    seconds: set[Second] = {second};
    firsts.add(first);
    from_list = set([first, equal_fields, first]);
    word_values: dict[str, int] = {"one": 10};
    first_values: dict[First, int] = {first: 30, equal_fields: 40};
    second_values: dict[Second, int] = {second: 70};
    first_values[first] = 31;
    firsts.discard(equal_fields);
    return len(words) + len(firsts) + len(seconds) + len(from_list)
        + word_values["one"] + first_values[first] + first_values[equal_fields]
        + second_values[second];
}
