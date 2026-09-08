"""A conditional freeze consumes its source only on the taken branch."""

obj Buffer {
    has value: int = 7;
}

def read(freeze_it: bool) {
    buffer: own Buffer = Buffer();
    if freeze_it {
        snapshot = imm buffer;
        print(snapshot.value);
    } else {
        print(buffer.value);
    }
}
