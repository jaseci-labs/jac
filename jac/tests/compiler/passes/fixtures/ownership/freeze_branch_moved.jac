"""The joined path cannot use a source that either branch may have moved."""

obj Buffer {
    has value: int = 7;
}

def read(freeze_it: bool) {
    buffer: own Buffer = Buffer();
    if freeze_it {
        snapshot = imm buffer;
    }
    print(buffer.value);
}
