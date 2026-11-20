obj Buffer { has n: int = 0; }
obj View { has target: &Buffer; }

def make_view -> own View {
    b: own Buffer = Buffer(n=3);
    v: own View = View(target=&b);
    return v;
}

with entry {
    v: own View = make_view();
    print(v.target.n);
}
