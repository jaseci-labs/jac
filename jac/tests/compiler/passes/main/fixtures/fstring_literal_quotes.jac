"""Quote chars in f-string literal text are content, not delimiters."""

with entry {
    a = "x";
    b = "y";
    print(f"one '{a}'");
    print(f"two '{a}' and '{b}'");
    print(f"nums '{1}' '{2}' '{3}'");
    print(f'dq "{a}" and "{b}"');
    print(f"{a}' and '{b}");
    print(f"{a}' not supported");
    print(f"{'inner'}{a}");
    print(rf"raw '{a}' and '{b}'");
}
