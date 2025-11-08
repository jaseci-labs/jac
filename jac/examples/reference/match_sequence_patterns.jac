with entry {
    data = [1, 2, 3];
    match data {
        case [1, 2, 3]:
            print("Matched");
        case _:
            print("Not Found");
    }
}
