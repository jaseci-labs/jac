"""Fixture: a walker event ability that happens to be named `drop`.

`drop` is an ordinary identifier, so `can drop with Bomb entry` is an event
ability, not the walker's destructor hook. The walker, the function that
spawns it, and the unrelated function beside them all lower natively, while
`Crate`'s `def drop` still runs as a destructor.
"""

glob dropped: int = 0;

node World {}

node Bomb {
    has damage: int = 1;
}

obj Crate {
    has tag: int = 0;

    def drop {
        dropped += self.tag;
    }
}

walker FlyerTick {
    has hits: int = 0;

    can begin with World entry {
        visit [-->];
    }

    can drop with Bomb entry {
        self.hits += here.damage;
    }
}

def load_things(n: int) -> int {
    return n * 2;
}

def fly_over -> int {
    world = World();
    world ++> Bomb(damage=3);
    world ++> Bomb(damage=4);
    tick = world spawn FlyerTick();
    return tick.hits;
}

def release_crate {
    crate = Crate(tag=5);
}

def drop_count -> int {
    return dropped;
}

with entry {
    print(fly_over(), load_things(4));
}
