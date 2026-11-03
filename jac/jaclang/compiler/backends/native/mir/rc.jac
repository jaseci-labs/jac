glob RC_CONSUMING_OPS: list[MirOp] = [MirOp.STORE, MirOp.RET],
     UNWIND_RECORD_WORDS: int = 3;

class MirRcError(Exception) {}

obj MirRcState {
    has fn: MirFunction,
        ref_slots: list[MirValue] = [],
        immortal: set[int] = set(),
        parents: dict[int, int] = {},
        joins: dict[int, list[int]] = {},
        pending: dict[int, MirValue] = {},
        out: list[MirInstr] = [];

    def run;
    def rewrite(blk: MirBlock);
    def consume(value: MirValue) -> MirValue;
    def release(value: MirValue);
    def release_slots;
    def last_uses(blk: MirBlock) -> dict[int, int];
    def base_of(value_id: int) -> int;
    def bases_of(value_id: int) -> list[int];
    def initialize_slots;
    def carry_crossing;
    def owned_here(instr: MirInstr) -> bool;
    def end_temporaries;
    def move_temps(blk: MirBlock);
    def temp_ending(instrs: list[MirInstr], start: int, temp: MirValue) -> int;
    def protected_regions(
        labels: dict[str, MirBlock], succs: dict[str, list[str]]
    ) -> list[tuple[str, str, MirValue]];

    def temp_keeps(bits: dict[int, int]) -> dict[int, int];
    def temp_uses(instr: MirInstr, keeps: dict[int, int]) -> int;
    def temp_defs(instr: MirInstr, bits: dict[int, int]) -> int;
    def temp_end(slot: MirValue) -> list[MirInstr];
}

def mir_insert_rc(fn: MirFunction);

def mir_insert_unwind(mir: MirModule);

def mir_unwind_cleanup(fn: MirFunction, slots: list[MirValue]) -> MirFunction;

def mir_register_unwind(fn: MirFunction, slots: list[MirValue], cleanup: str);
