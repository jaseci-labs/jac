# Enum-only module for the cross-module enum lowering regression (#7851).
# opcodes_entry imports opcodes_use_mid, which imports this module, so the
# native pass walks this module AFTER the module whose glob and obj field
# types reference Opcode.

enum Opcode { NOP = 0, LOADI = 1, ADDK = 2, HALT = 3 }
