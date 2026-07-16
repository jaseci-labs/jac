obj Buffer {
    has n: int = 0;
}

def use1(x: Buffer) { }

def run {
    in Region() {
        x = Buffer();
        flow use1(x) ;
    }
}
