"""Native cross-module union-return fixture (issue #6659 Bug 3): the library
returns an OSP node behind an `Area | None` union, exposes a function that takes
the non-optional `Area`, and a walker that reads a field off `Area`. A consumer
that narrows the union (`x is not None`) must then be able to (a) read a field
off it, (b) pass it to a function typed `Area`, and (c) use it as a spawn
target. All three were the app-level cascade the issue describes (E1053 / E1115
/ E1099 / runtime crash), rooted in the imported node layout not being sound
across the boundary."""

node Area { has tag: int = 0; }

walker Probe {
    has hits: int = 0;
    can go with Area entry {
        self.hits += here.tag;
    }
}

def area_or_none(flag: bool) -> Area | None {
    if flag {
        return Area(tag=5);
    }
    return None;
}

def take(a: Area) -> int {
    return a.tag;
}
