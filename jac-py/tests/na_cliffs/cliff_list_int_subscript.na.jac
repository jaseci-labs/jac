# na cliff: list[int] subscript. jac-py core site: Python/ marshal Reader.r_byte
# indexes `self.data[self.pos]` on every byte. Memory: na-container-capabilities.
def r_byte(data: list[int], pos: int) -> int {
    b = data[pos];
    return b & 0xFF;
}

def use -> int {
    return r_byte([227, 2, 0], 0);
}

with entry {
    print(use());
}
