struct opcode_metadata {
    unsigned char valid_entry;
    unsigned char instr_format;
    unsigned short flags;
};

static const struct opcode_metadata _PyOpcode_opcode_metadata[4] = {
    [1] = { 1, 0, 0 },
    [3] = { 1, 0, 1 },
};

int
opcode_is_valid(int opcode)
{
    if (opcode < 0 || opcode >= 4) {
        return 0;
    }
    return _PyOpcode_opcode_metadata[opcode].valid_entry;
}
