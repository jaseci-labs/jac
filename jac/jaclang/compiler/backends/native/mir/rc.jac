import os;
import sys;

glob TEMP_BATCH_BITS: int = 62;

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
        out: list[MirInstr] = [],
        released_early: bool = False;

    def run;
    def rewrite(blk: MirBlock);
    def consume(value: MirValue) -> MirValue;
    def release(value: MirValue);
    def release_slots;
    def last_uses(blk: MirBlock) -> dict[int, int];
    def bases_of(value_id: int) -> list[int];
    def initialize_slots;
    def carry_crossing;
    def owned_here(instr: MirInstr) -> bool;
    def end_temporary_batch(temps: list[MirValue]);
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

obj MirOwnState(MirRcState) {
    has mir: (MirModule | None) = None,
        owning: set[int] = set(),
        forgets: set[int] = set(),
        moved: set[int] = set(),
        inputs: set[int] = set(),
        defs: dict[int, MirInstr] = {},
        final_loads: dict[int, int] = {},
        movable_temps: set[int] = set(),
        carried: dict[int, MirValue] = {},
        fallbacks: list[str] = [],
        temp_places: dict[int, list[MirValue]] = {},
        borrowed_carry: dict[int, MirValue] = {};

    override def run;
    override def rewrite(blk: MirBlock);
    override def consume(value: MirValue) -> MirValue;
    override def release_slots;
    override def owned_here(instr: MirInstr) -> bool;
    def index_values;
    def classify;
    def owned_source(value: MirValue) -> bool;
    def find_movable_temps;
    def store(instr: MirInstr);
    def call(instr: MirInstr);
    def escape(instr: MirInstr);
    def slot_root(value: MirValue) -> tuple[(MirValue | None), (MirInstr | None)];
    def movable(slot: MirValue, load: (MirInstr | None)) -> bool;
    def place_borrowed(place: MirValue) -> bool;
    def copy_text(value: MirValue) -> MirValue;
    def copy_bytes(value: MirValue) -> MirValue;
    def copy_tuple(value: MirValue) -> MirValue;
    def runtime_extern(name: str) -> tuple[list[MirType], MirType];
    def share(value: MirValue) -> MirValue;
    def settle_moved;
}

def mir_insert_rc(fn: MirFunction, mir: (MirModule | None) = None);

def mir_insert_unwind(mir: MirModule);

def mir_unwind_cleanup(fn: MirFunction, slots: list[MirValue]) -> MirFunction;

def mir_register_unwind(fn: MirFunction, slots: list[MirValue], cleanup: str);
