"""Reference counting over MIR.

Lowering never retains or releases. This pass decides it from the values'
ownership: a value a call or allocation returns is owned (+1); a load,
a parameter or a constant is borrowed. A store into a local slot and a
return consume their operand: an owned value moves, a borrowed one is
retained first. A local slot owns what it holds, so a store releases the
slot's previous value and a return releases every slot. An owned value
nothing consumes is released right after its last use in its block, where a
use of a part taken from a value (a string's data pointer) counts as a use of
the value, so the parts never outlive it.
String literals are immortal, so they are neither retained nor released.
A store into heap memory (a field) releases what it overwrites, and a load
of a reference from heap memory is retained, because the heap can change
under a borrowed copy. Functions marked `manual_rc` (generated drop and
trace functions) manage counts themselves and are left alone."""
glob RC_CONSUMING_OPS: list[MirOp] = [MirOp.STORE, MirOp.RET];

class MirRcError(Exception) {}

obj MirRcState {
    has fn: MirFunction,
        ref_slots: list[MirValue] = [],
        immortal: set[int] = set(),
        parents: dict[int, int] = {},
        pending: dict[int, MirValue] = {},
        out: list[MirInstr] = [];

    def run;
    def rewrite(blk: MirBlock);
    def consume(value: MirValue) -> MirValue;
    def release(value: MirValue);
    def release_slots;
    def last_uses(blk: MirBlock) -> dict[int, int];
    def base_of(value_id: int) -> int;
    def initialize_slots;
}

def mir_insert_rc(fn: MirFunction);
