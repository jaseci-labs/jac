import from nadefault_cyc_a { fa }

def fb(n: int) -> int {
    if n <= 0 {
        return 0;
    }
    return fa(n - 1) + 1;
}
