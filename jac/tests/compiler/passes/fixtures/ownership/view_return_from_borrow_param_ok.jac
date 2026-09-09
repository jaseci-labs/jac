obj Buffer { has n: int = 0; }
obj View { has target: &Buffer; }

def open_view(b: &Buffer) -> View { return View(target=b); }

with entry {
    b: own Buffer = Buffer(n=5);
    v = open_view(&b);
    print(v.target.n);
}
