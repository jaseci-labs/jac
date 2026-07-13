obj Buffer { has n: int = 0; }

def make() -> list {
    region {
        x = Buffer();
        return [x];
    }
}
