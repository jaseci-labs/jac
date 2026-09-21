node x {}

edge e : Root --> x {
    has name: str;
}

with entry {
    nodes = root +>: e(name="hello") :+> x();
    print(nodes);
}
