with entry {
    data = {"key1": 1, "key2": 2, "232": 3453};
    match data {
        case {"key1" : 1, "key2" : 2, **rest}:
            print(
                f"Matched a mapping with key1 and key2. Rest: {rest}"
            );
    }
}
