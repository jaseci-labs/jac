glob a: str, b: str;
glob c: str;

def do() {
    global a, b, c ;

    (a, b, c) = ("Welcome", "to", "Jaseci!");
}

with entry {
    (a, b, c) = ("Hello", "World", "!");
    print(a, b, c);
    do();
    print(a, b, c);
}
