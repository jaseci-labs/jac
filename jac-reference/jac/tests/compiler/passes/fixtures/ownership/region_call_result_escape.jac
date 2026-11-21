obj Buffer {
    has n: int = 0;
}

def build -> Buffer {
    return Buffer();
}

def run {
    xs: list[Buffer] = [];
    in Region() {
        xs.append(build());
    }
    print(len(xs));
}
