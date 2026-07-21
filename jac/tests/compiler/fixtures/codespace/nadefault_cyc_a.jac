import from nadefault_cyc_b { fb }

def fa(n: int) -> int {
    if n <= 0 {
        return 0;
    }
    return fb(n - 1) + 1;
}
