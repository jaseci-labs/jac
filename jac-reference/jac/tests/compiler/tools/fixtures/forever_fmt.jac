with entry {
    x = 0;
    forever {
        x += 1;
        if x > 3 {
            break;
        }
    }
    print(x);
}
