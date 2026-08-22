enum Color { RED = "red", GREEN = "green" }

enum Prio { LOW = 1, HIGH = 2 }

def pick_color(i: int) -> Color {
    if i == 0 {
        return Color.RED;
    }
    return Color.GREEN;
}

def pick_prio(i: int) -> Prio {
    if i == 0 {
        return Prio.LOW;
    }
    return Prio.HIGH;
}

def:pub color_value_len(i: int) -> int {
    c = pick_color(i);
    return len(c.value);
}

def:pub color_name_concat(i: int) -> int {
    c = pick_color(i);
    s: str = "x" + c.name;
    return len(s);
}

def:pub prio_name_len(i: int) -> int {
    p = pick_prio(i);
    return len(p.name);
}

def:pub prio_value_of(i: int) -> int {
    p = pick_prio(i);
    return p.value;
}

with entry {
    color_value_len(0);
}
