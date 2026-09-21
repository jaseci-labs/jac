walker Inner {
    can go with Root entry {
        report {"inner": True};
    }
}

walker:protect Outer {
    has tag: str = "outer";

    can go with Root entry {
        root spawn Inner();
        report {"outer": self.tag};
    }
}

walker:protect CountThings {
    has total: int = 0;

    can go with Root entry {
        self.total += 1;
    }
}

walker:protect SelfReporter {
    has tag: str = "me";

    can go with Root entry {
        report self;
    }
}

def:protect list_things(n: int = 2) -> list[dict[str, any]] {
    return [{"name": f"t{i}", "idx": i} for i in range(n)];
}

def:protect nothing -> None {
    return None;
}

def:protect spawn_inside(tag: str = "x") -> dict[str, any] {
    w = root spawn Outer(tag=tag);
    return {"tag": w.tag, "seen": len(w.reports)};
}

def:protect spawn_and_return_walker(tag: str = "y") -> Outer {
    return root spawn Outer(tag=tag);
}
