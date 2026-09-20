import json;

with entry {
    values = json.loads("[1, 2]");
    iterator = iter(values);
}

with entry {
    values.append(3);
    print(next(iterator));
    print(len(values));
}
