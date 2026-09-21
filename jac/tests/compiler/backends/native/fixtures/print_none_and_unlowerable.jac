def run_cases {
    print("start");
    print(None);
    x: (int | None) = None;
    print(x);
    print(1, None, "tail");
    print("end");
}

with entry {
    run_cases();
}
