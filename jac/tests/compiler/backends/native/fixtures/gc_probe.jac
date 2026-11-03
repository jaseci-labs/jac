import gc;

obj Node {
    has label: str = "";
}

with entry {
    nodes = [Node(label=str(i)) for i in range(100)];
    nodes = [];
    found = gc.collect();
    print("collect returns an int", isinstance(found, int));
    print("collect is never negative", found >= 0);
    print("a full collection", gc.collect(2) >= 0);
}
