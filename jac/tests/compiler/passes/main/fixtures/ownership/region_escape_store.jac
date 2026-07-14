obj Box { has item: any = None; }
obj Buffer { has n: int = 0; }

def stash(b: Box) -> None {
    region {
        x = Buffer();
        b.item = x;
    }
}
