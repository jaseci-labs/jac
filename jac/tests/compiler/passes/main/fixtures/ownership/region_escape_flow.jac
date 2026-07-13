obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

def run() -> None {
    region {
        x = Buffer();
        flow use1(x);
    }
}
