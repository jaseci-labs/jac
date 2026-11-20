def tail_forever(x: int) -> int {
    if x > 0 {
        forever {
            x = x + 1;
            if x > 5 {
                break;
            }
        }
    }
    return x;
}
