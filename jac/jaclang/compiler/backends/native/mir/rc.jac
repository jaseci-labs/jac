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
    def carry_across_blocks;
}

def mir_insert_rc(fn: MirFunction);
