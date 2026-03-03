with entry {
    for i in range(0, 5) {
        if i == 1 { continue; }
        print(i);
        if i == 3 { break; }
    } else {
        print("done");
    }
}
