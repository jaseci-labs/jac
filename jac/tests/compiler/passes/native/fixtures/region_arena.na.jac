obj Box { has v: int = 0; }

def region_sum(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        region {
            b: own Box = Box(v=i);
            total = total + b.v;
        }
        i = i + 1;
    }
    return total;
}
