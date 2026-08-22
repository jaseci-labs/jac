node Item {
    has val: int;
}

walker Collector {
    has total: int = 0;

    can grab with Item entry {
        self.total = self.total + here.val;
    }
}

def collect(a: int, b: int) -> int {
    c = Collector();
    c spawn Item(val=a);
    c spawn Item(val=b);
    return c.total;
}

with entry {
    print("total:", collect(4, 5));
}
