"""Generators over MIR.

Lowering turns a generator function into two functions: a start function
under the generator's own symbol, which allocates the frame (`frame.new`),
copies its arguments into the frame (`frame.field`) and returns a `JacIter`
over the resume function; and the resume function, marked `resumable`, whose
body is ordinary MIR with a `yield` instruction at each suspension point.

This pass runs after reference counting. It gives every local slot of a
resume function a frame offset after the 40-byte header (resume point at
+0, then the pending-exception flag, type, object and message), splits each
block at its yields into a store of the element into the out cell, a store of
the resume point and `ret true`, and starts the function with a dispatch on
the resume point. A value defined before a yield and used after it, on a path
that skips its definition, lives in the frame too. Returns store the done
mark and `ret false`. It then lowers `frame.new` and `frame.field` in every
function to runtime calls and address arithmetic, and adds the drop function
that releases the frame's reference slots."""
glob GEN_FRAME_HEADER: int = 40,
     GEN_DONE: int = -1;

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
}

def mir_lower_generators(mir: MirModule);

def mir_frame_bytes(t: MirType, mir: MirModule) -> int;

def mir_frame_field(
    fn: MirFunction, out: list[MirInstr], base: MirValue, offset: int, t: MirType
) -> MirValue;

def mir_lower_frames(mir: MirModule, fn: MirFunction);
