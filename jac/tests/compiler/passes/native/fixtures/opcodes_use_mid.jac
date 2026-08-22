# Middle module for the cross-module enum lowering regression (#7851).
# The glob and obj field types reference an enum defined in opcodes_mod, a
# module the native pass walks after this one.  Lowering used to miss the
# not-yet-registered enum, failing to lower the containing dict type; the
# structural enum fallback lowers Opcode to i64.

import from opcodes_mod { Opcode }

glob WEIGHTS: dict[Opcode, int] = {
         Opcode.LOADI: 100,
         Opcode.ADDK: 10,
         Opcode.HALT: 1
     };

obj OpcodeTally {
    has current: Opcode = Opcode.HALT,
        counts: dict[Opcode, int] = {};
}

def tally_program -> int {
    t: OpcodeTally = OpcodeTally();
    t.counts[Opcode.LOADI] = 2;
    t.counts[Opcode.ADDK] = 3;
    t.counts[Opcode.HALT] = 1;
    total: int = 0;
    if t.current == Opcode.HALT {
        total = 1000;
    }
    total += t.counts[Opcode.LOADI] * WEIGHTS[Opcode.LOADI];
    total += t.counts[Opcode.ADDK] * WEIGHTS[Opcode.ADDK];
    total += t.counts[Opcode.HALT] * WEIGHTS[Opcode.HALT];
    return total;
}
