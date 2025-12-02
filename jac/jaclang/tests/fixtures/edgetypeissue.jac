node x {}

edge e {
    has name: str;
}

with entry {
    nodes = root +>: e(name="hello") :+> x();
    print(nodes);
}
