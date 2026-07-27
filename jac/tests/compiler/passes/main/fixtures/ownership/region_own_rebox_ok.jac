obj Buffer {
    has name: str = "";
}

def run -> str {
    s = "";
    in Region() {
        b = Buffer();
        b.name = "hi";
        s = own b.name;
    }
    return s;
}
