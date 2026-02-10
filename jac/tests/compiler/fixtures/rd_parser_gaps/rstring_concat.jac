# Raw string implicit concatenation with regular strings
with entry {
    x = r"\n" "hello";
    y = b"bytes" b"more";
    z = r"\t" r"\n";
}
