obj Box {
    has value: own Box | None = None;
}
def remove(b: &Box) -> own Box | None {
    return take(b.value);
}
