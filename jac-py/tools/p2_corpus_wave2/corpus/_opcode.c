/* Header-free extract from Modules/_opcode.c (is_valid, has_arg). */

#include <stdint.h>

#define OPCODE_TABLE_SIZE 267
#define HAS_ARG_FLAG 1

struct opcode_metadata {
    uint8_t valid_entry;
    uint8_t instr_format;
    uint16_t flags;
};

static const struct opcode_metadata _PyOpcode_opcode_metadata[OPCODE_TABLE_SIZE] = {
    [27] = { 1, 0, 0 },
    [35] = { 1, 0, 0 },
    [84] = { 1, 0, HAS_ARG_FLAG },
};

#define IS_VALID_OPCODE(OP) \
    (((OP) >= 0) && ((OP) < OPCODE_TABLE_SIZE) && \
     (_PyOpcode_opcode_metadata[(OP)].valid_entry))

#define OPCODE_HAS_ARG(OP) (_PyOpcode_opcode_metadata[OP].flags & HAS_ARG_FLAG)

int
opcode_is_valid(int opcode)
{
    return IS_VALID_OPCODE(opcode);
}

int
opcode_has_arg(int opcode)
{
    return IS_VALID_OPCODE(opcode) && OPCODE_HAS_ARG(opcode);
}
