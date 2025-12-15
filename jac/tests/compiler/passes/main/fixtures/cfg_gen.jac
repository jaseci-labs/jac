with entry {
    x = 5;
    y = 3;
    if x > 3 {
        z = x + y;
    } elif x == 0 {
        z = y;
    } else {
        z = x - y;
    }

    for i in range(0, 10) {
        z = z + 1;
    }

    while z < 10 {
        z = z + 2;
    }
}
