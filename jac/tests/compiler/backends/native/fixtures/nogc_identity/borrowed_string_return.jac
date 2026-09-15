def pick -> str {
    items: list[str] = ["abc"];
    return items[0];
}

with entry {
    s = pick();
    print(len(s));
    print(ord(s[1]));
    print(s[2]);
}
