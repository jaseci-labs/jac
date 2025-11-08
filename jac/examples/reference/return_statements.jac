def foo -> int{
    a = 42;
    return a;
}

with entry {
    print("Returned:", foo());
}
