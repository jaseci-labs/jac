# Entry module for the cross-module enum lowering regression (#7851).
# Importing only the middle module makes the native pass discover modules in
# the order [opcodes_use_mid, opcodes_mod]: the module whose glob and obj
# field are typed dict[Opcode, int] is walked before the module defining
# Opcode.

import from opcodes_use_mid { tally_program }

def imported_enum_tally -> int {
    return tally_program();
}

with entry {
    _x: int = 1;
}
