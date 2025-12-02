def bar(some_list: list) {
    invalid_index = 4;
    print(some_list[invalid_index]);  # This should fail.
}

def foo() {
    bar([0, 1, 2, 3]);
}

with entry {
    foo();
}
