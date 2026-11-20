def tail_while(x: int) -> int {
    if x > 0 {
        while x < 5 {
            x = x + 1;
        }
    }
    return x;
}
