obj Buffer { has n: int = 0; }

def run() -> None {
    holder: Buffer = Buffer();
    region {
        x = Buffer();
        holder = x;
    }
    print(holder.n);
}
