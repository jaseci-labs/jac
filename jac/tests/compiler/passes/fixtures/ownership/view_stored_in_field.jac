obj Buffer { has n: int = 0; }
obj View { has target: &Buffer; }
obj Holder { has kept: View | None = None; }

with entry {
    b: own Buffer = Buffer(n=3);
    v = View(target=&b);
    h: own Holder = Holder();
    h.kept = v;
}
