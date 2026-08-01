obj Entry {
    has path: own str,
        size: int,
        sha: own str;
}

with entry {
    e = Entry(path="a", size=1, sha="b");
    print(e.size);
}
