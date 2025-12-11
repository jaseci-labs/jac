with entry {
    a: list[str] = [];
    a.append("str1");
    a.append("str2");
    a.pop();
    a.pop();

    str(6).count("6");
    int("5");

    b: dict[str, list[int]] = {"a": [2, 3, 4]};
    b.keys();
    b["a"].append(9);

    dir(a);
}
