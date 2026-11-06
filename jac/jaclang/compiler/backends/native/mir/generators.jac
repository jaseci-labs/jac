glob GEN_FRAME_HEADER: int = 40,
     GEN_DONE: int = -1,
     GEN_PENDING_TYPE: int = 8,
     GEN_PENDING_MESSAGE: int = 16,
     GEN_PENDING_ORIGIN: int = 24,
     GEN_OUT_CELL: int = 32;

class MirGenError(Exception) {}

obj MirGenState {
    has mir: MirModule,
        fn: MirFunction,
        offsets: dict[int, int] = {},
        addresses: dict[int, MirValue] = {},
        cursor: int = GEN_FRAME_HEADER,
        resumes: list[MirBlock] = [],
        held: list[MirValue] = [];

    def run;
    def allocate(t: MirType) -> int;
    def rewrite_returns(blk: MirBlock, frame: MirValue);
    def split(blk: MirBlock, frame: MirValue, out: MirValue) -> (MirBlock | None);
    def substitute_slots;
    def reachable_avoiding(home: str, successors: dict[str, list[str]]) -> set[str];
    def spill_live_values(frame: MirValue);
    def dispatch(prologue: list[MirInstr], frame: MirValue, first: MirBlock);
    def drop_function -> MirFunction;
    def close_on_drop(
        made: MirFunction, opening: MirBlock, frame: MirValue
    ) -> MirBlock;
}

def mir_lower_generators(mir: MirModule);

def mir_frame_bytes(t: MirType, mir: MirModule) -> int;

def mir_frame_field(
    fn: MirFunction, out: list[MirInstr], base: MirValue, offset: int, t: MirType
) -> MirValue;

def mir_lower_frames(mir: MirModule, fn: MirFunction);
