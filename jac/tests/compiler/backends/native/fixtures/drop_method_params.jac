"""Fixture: a method named `drop` that takes arguments.

A destructor hook is called with nothing but the object, so `Shelf.drop(name)`
is an ordinary method that the release function never calls. `Crate`'s
`def drop` still runs as a destructor, and `Tray`, whose own `drop` takes an
argument, does not fall back to the hook it would have inherited.
"""

glob dropped: int = 0;

obj Shelf {
    has pics: dict[str, int] = {};

    def drop(name: str) {
        if name in self.pics {
            self.pics.pop(name);
        }
    }
}

obj Crate {
    has tag: int = 0;

    def drop {
        dropped += self.tag;
    }
}

obj Tray(Crate) {
    def drop(extra: int) {
        dropped += extra * 100;
    }
}

def shelf_probe -> int {
    shelf = Shelf();
    shelf.pics["a"] = 1;
    shelf.pics["b"] = 2;
    shelf.drop("a");
    return len(shelf.pics);
}

def release_crate {
    crate = Crate(tag=5);
}

def release_tray {
    tray = Tray(tag=9);
}

def tray_probe -> int {
    tray = Tray(tag=9);
    tray.drop(3);
    return dropped;
}

def drop_count -> int {
    return dropped;
}

with entry {
    print(shelf_probe());
}
