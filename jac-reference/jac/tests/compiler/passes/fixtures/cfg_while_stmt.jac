with entry {
    x = 0;
    while x < 5 {
        x = x + 1;
        if x == 2 { continue; }
        print(x);
        if x == 4 { break; }
    } else {
        print("done");
    }
}
