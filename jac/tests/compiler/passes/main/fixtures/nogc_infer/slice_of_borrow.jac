def head(src: &str, n: int) -> own str {
    piece = src[0:n];
    return piece;
}

with entry {
    h: own str = head(&"abcdef", 3);
    print(h);
}
