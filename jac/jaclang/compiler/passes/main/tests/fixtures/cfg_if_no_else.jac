def test_if_without_else(x: int) {
    if (x > 0) {
        print("Positive");
    }
    print("Done");
}

with entry {
    test_if_without_else(5);
    test_if_without_else(-3);
}