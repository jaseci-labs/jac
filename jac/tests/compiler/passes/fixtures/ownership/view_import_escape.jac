import from .view_import_base { Buffer, View }
obj Child(View) {}
def make_view -> own Child {
    b: own Buffer = Buffer(n=3);
    v: own Child = Child(target=&b);
    return v;
}

with entry {
    v: own Child = make_view();
    print(v.target.n);
}
