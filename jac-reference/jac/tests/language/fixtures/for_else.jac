with entry {
    total = 0;
    for i in [1, 2, 3] {
        total += i;
    } else {
        total += 1000;
    }
    print("Sum: ", total);

    for i in [1, 2, 3] {
        if i == 2 {
            break;
        }
    } else {
        print("Skipped");
    }
    print("Done");
}
