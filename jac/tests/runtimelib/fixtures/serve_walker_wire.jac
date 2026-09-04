node Thing {
    has name: str = "";
}

walker Seed {
    has count: int = 3;

    can go with Root entry {
        for i in range(self.count) {
            here ++> Thing(name=f"t{i}");
        }
    }
}

walker Inner {
    can go with Root entry {
        report {"inner": True};
    }
}

walker Outer {
    has tag: str = "outer";

    can go with Root entry {
        root spawn Inner();
        report {"outer": self.tag};
    }
}

walker CountThings {
    has prefix: str = "t";
    has total: int = 0;

    can start with Root entry {
        visit [-->];
    }

    can count with Thing entry {
        if here.name.startswith(self.prefix) {
            self.total += 1;
        }
    }
}

def list_things(n: int = 2) -> list {
    return [{"name": f"t{i}", "idx": i} for i in range(n)];
}

def nothing -> None {
    return None;
}

def spawn_inside(tag: str = "x") -> dict {
    w = root spawn Outer(tag=tag);
    return {"tag": w.tag, "seen": len(w.reports)};
}

def spawn_and_return_walker(tag: str = "y") -> Outer {
    return root spawn Outer(tag=tag);
}
