obj Buffer { has n: int = 0; }

with entry {
    v: val Buffer = Buffer();
    r: &mut Buffer = &mut v;
}
