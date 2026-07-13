obj Buffer { has n: int = 0; }

def run() -> None {
    region {
        x = Buffer();
        x.n = 1;
        print(x.n);
    }
}
