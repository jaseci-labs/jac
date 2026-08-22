def opcode_is_valid(opcode: int) -> int {
    if (opcode < 0) or (opcode >= 267) {
        return 0;
    }
    if (opcode == 27) or (opcode == 35) or (opcode == 84) {
        return 1;
    }
    return 0;
}

def opcode_has_arg(opcode: int) -> int {
    if not opcode_is_valid(opcode) {
        return 0;
    }
    if opcode == 84 {
        return 1;
    }
    return 0;
}
