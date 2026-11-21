"""F-string literal text segments must keep quote characters verbatim."""

glob a = "AA",
     b = "BB";

with entry {
    print(f"'{a}' '{b}'");
    print(f"-o '{a}' '{b}' end");
    print(f"{a}r'q'{b}");
    print(f'"{a}" "{b}"');
    print(f"x '{a}' y");
}
