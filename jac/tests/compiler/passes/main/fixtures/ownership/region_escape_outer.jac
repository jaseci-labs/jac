obj Buffer {
    has n: int = 0;
}

def run {
    holder: Buffer = Buffer();
    in Region() {
        x = Buffer();
        holder = x;
    }
    print(holder.n);
}
