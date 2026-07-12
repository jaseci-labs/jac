obj Buffer { has n: int = 0; }

def run() -> None {
    outer = None;
    region {
        x = Buffer();
        outer = (x, );
    }
    print(outer);
}
