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
    has total: int = 0;

    can go with Root entry {
        self.total += 1;
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
