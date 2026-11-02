"""`del xs[a:b]` on lists of scalars and of strings."""

def run {
    a = [0, 1, 2, 3, 4, 5, 6];
    del a[2:4];
    print(a);
    del a[-2:];
    print(a);
    del a[:1];
    print(a);
    del a[5:];
    print(a);
    del a[3:1];
    print(a);
    names = ["x", "y", "z", "w", "v"];
    mark = 2;
    del names[mark:];
    print(names, len(names));
    words = ["p", "q", "r"];
    del words[1:2];
    print(words);
    del words[:];
    print(words, len(words));
}

with entry {
    run();
}
