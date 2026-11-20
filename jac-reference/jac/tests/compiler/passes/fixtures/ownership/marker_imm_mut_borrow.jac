obj Buffer { has n: int = 0; }

with entry {
    v: imm Buffer = Buffer();
    r: &mut Buffer = &mut v;
}
