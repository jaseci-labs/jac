"""An annotated container keeps its element type during assignment narrowing."""
obj Base {}
obj First(Base) {}
obj Second(Base) {}

def collect(enabled: bool) -> list[Base] {
    if enabled {
        items: list[Base] = [First()];
        items.extend([Second()]);
        return items;
    }
    return [];
}

def invalid(enabled: bool) {
    if enabled {
        items: list[Base] = [First()];
        items.append("not a Base");
    }
}
