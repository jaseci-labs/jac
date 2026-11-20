with entry {
    x = {"a": "apple", "b": "banana"};
    ((a, apple), (b, banana)) = x.items();
    [[a2, apple2], [b2, banana2]] = x.items();
    ([a3, apple3], [b3, banana3]) = x.items();
    [(a4, apple4), (b4, banana4)] = x.items();
    print(
        a,
        apple,
        b,
        banana,
        a2,
        apple2,
        b2,
        banana2,
        a3,
        apple3,
        b3,
        banana3,
        a4,
        apple4,
        b4,
        banana4
    );
}
