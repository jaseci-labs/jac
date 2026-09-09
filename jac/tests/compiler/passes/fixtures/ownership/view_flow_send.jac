obj Buffer { has n: int = 0; }
obj View { has target: &Buffer; }

def read(v: View) -> int { return v.target.n; }

with entry {
    b: own Buffer = Buffer(n=3);
    v = View(target=&b);
    h = flow read(v);
    print(wait h);
}
