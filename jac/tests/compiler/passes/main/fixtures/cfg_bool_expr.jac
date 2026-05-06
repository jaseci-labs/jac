with entry {
    x = 5;
    if (x < 3 and x < 10) or (x > 20 and x < 30) {
        print(x);
        x = x + 1;
    }
    print("done");
    if (x > 0 or x == -1) and (x < 100 or x == 200) {
        print("matched");
    }
    print("end");
    if y {
        print("y is true");
    }
    print("finished");
}
