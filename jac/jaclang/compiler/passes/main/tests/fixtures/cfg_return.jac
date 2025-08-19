def test_return_direct() {
    print("Before return");
    return;
    print("After return");
}

with entry {
    test_return_direct();
}