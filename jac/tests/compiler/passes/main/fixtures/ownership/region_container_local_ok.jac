obj Buffer { has n: int = 0; }

def run() -> None {
    region {
        x = Buffer();
        items = [x];
        print(len(items));
    }
}
