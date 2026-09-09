obj Buffer {
    has n: int = 0;
}
obj View {
    has target: &Buffer;
}
obj Child(View) {}
def read(b: &Buffer) -> int {
    v = Child(target=b);
    return v.target.n;
}

with entry {
    b: own Buffer = Buffer(n=3);
    print(read(&b));
}
