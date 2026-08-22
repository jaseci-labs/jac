# Compiler IR for the P4 back track (PLAN.md P0.10).
#
# Source-location, instruction, basic-block, and compile-unit objects shared by
# codegen (AST -> IR) and the assembler (IR -> PyCode). The two consumers import
# FROM this module; neither imports the other, keeping an acyclic front-end DAG.
#
# na-clean leaf: no host calls, no import cycles. Location encoding matches
# CPython 3.14 (PEP 626); col offsets are 0-based byte offsets, NO_COLUMN = -1.

import from objects { PyObj }
import from opcode_meta { opcode_cache_count }
import from compiler_diagnostics { compiler_diagnostic }
import from compiler_symtable { sym_block }

# A source location. lineno/end_lineno are 1-based; col_offset/end_col_offset are
# 0-based. Matches CPython's `location` struct (Python/compile.c).
obj cloc {
    has lineno: int,
        end_lineno: int,
        col_offset: int,
        end_col_offset: int;
}

glob NO_LINE: int = -1,
     NO_COLUMN: int = -1;

def loc(lineno: int, end_lineno: int, col_offset: int, end_col_offset: int) -> cloc {
    return cloc(
        lineno=lineno,
        end_lineno=end_lineno,
        col_offset=col_offset,
        end_col_offset=end_col_offset
    );
}

# NO_LOCATION sentinel (CPython: all fields -1). Emitted as a NONE linetable entry.
def no_loc -> cloc {
    return loc(NO_LINE, NO_LINE, NO_COLUMN, NO_COLUMN);
}

# Two locations are equal only when all four fields agree (used by the linetable
# encoder to group consecutive same-location instructions).
def same_loc(a: cloc, b: cloc) -> bool {
    if a.lineno != b.lineno {
        return False;
    }
    if a.end_lineno != b.end_lineno {
        return False;
    }
    if a.col_offset != b.col_offset {
        return False;
    }
    if a.end_col_offset != b.end_col_offset {
        return False;
    }
    return True;
}

# A single IR instruction. oparg is the logical argument (0 for no-arg opcodes).
# For jumps, target_block is the destination basicblock id (resolved by the
# assembler to a code-unit offset); -1 means "not a jump".
obj cinstr {
    has opcode: int,
        oparg: int,
        loc: cloc,
        target_block: int = -1;
}

def mk_instr(opcode: int, oparg: int, lc: cloc) -> cinstr {
    return cinstr(opcode=opcode, oparg=oparg, loc=lc, target_block=-1);
}

def mk_jump(opcode: int, target: int, lc: cloc) -> cinstr {
    return cinstr(opcode=opcode, oparg=0, loc=lc, target_block=target);
}

# Active loop target pair for break/continue lowering (continue_blk, break_blk).
obj loop_frame {
    has continue_blk: basicblock,
        break_blk: basicblock,
        break_is_stub: bool = False;
}

# CFG builder: owns the current block and emits into unverified_cfg (Phase 4).
obj cfg_builder {
    has u: unverified_cfg,
        cur: basicblock,
        sym_top: sym_block | None = None,
        private: str | None = None,
        loop_stack: list[loop_frame] = [],
        # Suspendable function (generator/coroutine) PEP 479 protect start block id.
        generator_protect_start: int = -1,
        # END_ASYNC_FOR handler block id (async-for PEP 479 unwind region).
        async_for_end_async_block: int = -1,
        # While emitting an except handler body: the enclosing handler's inline
        # success epilogue = POP_EXCEPT + jump to fin (fin_inline block, backward
        # flag, and the fin handler block id for region targeting). A nested try
        # falling through emits that epilogue inline (CPython duplicates it per
        # path); handler_nest_depth counts active handler frames so nested try
        # regions carry the extra exception stack depth (CPython per-instruction
        # depths); handler_enclosing_unwind is the enclosing try's cleanup block
        # for retargeting nested handler-body regions.
        # handler_fallthrough_bind is the enclosing handler's `except ... as`
        # binding (None when unbound): inline epilogues must clear it
        # (LOAD_CONST None / store / delete) after POP_EXCEPT, matching CPython's
        # duplicated cleanup on every handler exit path.
        handler_fallthrough_fin: basicblock | None = None,
        handler_fallthrough_backward: bool = False,
        handler_fallthrough_fin_handler: int = -1,
        handler_fallthrough_bind: str | None = None,
        handler_enclosing_unwind: int = -1,
        handler_fell_through: bool = False,
        handler_nest_depth: int = 0;

    def emit(ins: cinstr) {
        self.cur.instrs.append(ins);
    }

    def push_loop(
        continue_blk: basicblock, break_blk: basicblock, break_is_stub: bool
    ) {
        self.loop_stack.append(
            loop_frame(
                continue_blk=continue_blk,
                break_blk=break_blk,
                break_is_stub=break_is_stub
            )
        );
    }

    def pop_loop {
        if len(self.loop_stack) > 0 {
            self.loop_stack = self.loop_stack[0:len(self.loop_stack) - 1];
        }
    }

    def current_loop -> loop_frame | None {
        if len(self.loop_stack) == 0 {
            return None;
        }
        return self.loop_stack[len(self.loop_stack) - 1];
    }

    def emit_op(opcode: int, oparg: int, lc: cloc) {
        self.emit(mk_instr(opcode, oparg, lc));
    }

    def emit_jump(opcode: int, target: int, lc: cloc) {
        self.emit(mk_jump(opcode, target, lc));
    }

    def new_block -> basicblock {
        return self.u.add_block();
    }

    def new_deferred_block -> basicblock {
        return self.u.add_deferred_block();
    }

    def use(b: basicblock) {
        # Lay out a deferred block at the current end of the layout list on first
        # use (CPython USE_LABEL). Already-placed blocks just become current.
        if not b.placed {
            b.placed = True;
            self.u.blocks.append(b);
        }
        self.cur = b;
    }
}

def new_cfg_builder(
    u: unverified_cfg,
    start_blk: basicblock,
    sym_top: sym_block | None = None,
    private: str | None = None
) -> cfg_builder {
    return cfg_builder(u=u, cur=start_blk, sym_top=sym_top, private=private);
}

# Statement lowering result: continuation location and whether the CFG path
# terminated (no fallthrough to the next statement).
obj stmt_cont {
    has loc: cloc,
        terminated: bool = False,
        # When >= 0, compile_exec resumes at this statement index (tail consumed).
        next_si: int = -1;
}

# A basic block: an ordered instruction list. The assembler lays blocks out in
# allocation order and resolves each jump's target_block to a code-unit offset.
obj basicblock {
    has id: int,
        instrs: list[cinstr],
        # False for a deferred block (allocated but not yet laid out). use() lays
        # it out at the current end of the layout list, mirroring CPython's split
        # of NEW_JUMP_TARGET_LABEL (allocate) from USE_LABEL (place).
        placed: bool = True,
        # True on match join/end blocks: the shared success target of match-arm
        # (and MatchOr alternative) success jumps. The flowgraph's small-exit
        # inliner only tail-duplicates into these blocks, keeping the pass scoped
        # to match the way optimize_swap_range is scoped to match arms. Other
        # constructs already emit CPython's post-optimizer shape by hand, so a
        # global inliner would mis-fire (e.g. on generator/async-for back-edges).
        exit_inline_ok: bool = False;
}

# Deferred comprehension cleanup handler (emitted after module RETURN_VALUE).
obj comp_handler {
    has region_index: int,
        fast_index: int,
        loc: cloc,
        second_fast_index: int = -1,
        swap_depth: int = 2,
        group: int = 0;
}

# Protected region for assemble_exception_table (comprehensions, try/finally).
obj except_region {
    has start_block: int,
        end_block: int,
        handler_block: int,
        stack_depth: int,
        preserve_lasti: bool = False;
}

# Unverified CFG plus compile metadata from codegen. Flowgraph verification
# produces verified_cfg; assembly accepts verified CFG only (Phase 2 contract).
obj unverified_cfg {
    has filename: str,
        name: str,
        qualname: str,
        firstlineno: int,
        argcount: int = 0,
        posonlyargcount: int = 0,
        kwonlyargcount: int = 0,
        flags: int = 0,
        varnames: list[str] = [],
        cellvars: list[str] = [],
        freevars: list[str] = [],
        consts: list[PyObj] = [],
        names: list[str] = [],
        blocks: list[basicblock] = [],
        next_block_id: int = 0,
        # Per-block entry stack depth (indexed by block id), stashed by
        # calculate_stackdepth on success so optimize_load_fast can seed each
        # block's abstract ref stack with the right number of incoming values.
        block_startdepths: list[int] = [],
        except_regions: list[except_region] = [],
        comp_handlers: list[comp_handler] = [],
        comp_handler_group: int = 0,
        # Comprehension loop-var slot whose borrowed copy is sitting on the
        # stack (left by STORE_FAST_LOAD_FAST at bind), awaiting consumption by
        # the first evaluated reference to that loop var. -1 = none pending.
        # Subsequent references emit LOAD_FAST_BORROW (CPython's scheme).
        comp_pending_borrow: int = -1,
        # >0 while emitting a comprehension body: enables coalescing of adjacent
        # LOAD_FAST_BORROW loads into LOAD_FAST_BORROW_LOAD_FAST_BORROW (CPython's
        # superinstruction peephole), scoped so ordinary code is untouched.
        comp_depth: int = 0,
        # Set by codegen on unsupported nodes; product_compile checks before
        # flowgraph verification (PLAN.md: no silent codegen paths).
        diag: compiler_diagnostic | None = None,
        # CPython keeps one dead small-int const (first 0..255 literal seen).
        dead_small_int_const: bool = False,
        # Set after MAKE_FUNCTION; suppresses dead small-int consts on call args.
        nested_code_emitted: bool = False,
        # except_region indices whose handler_block is the PEP 479 handler (filled at end).
        pending_pep479_regions: list[int] = [],
        # try/except unwind handler_block indices (filled after reraise epilogue).
        pending_try_unwind_regions: list[int] = [],
        # Inner try/finally success-path bounds for outer try/except wrapping.
        nested_try_finally_success_start: int = -1,
        nested_try_finally_success_end: int = -1,
        nested_try_finally_unwind_start: int = -1,
        # Last block of a nested try/except statement inside an outer try body;
        # the outer body span starts here so entries never overlap the inner
        # try's own regions (CPython table is per-instruction innermost).
        nested_try_except_end: int = -1,
        # First block (leading NOP) of the most recent nested try/except; the
        # enclosing handler's match span ends here when the nested try's own
        # regions carve out its body/handler coverage.
        nested_try_except_start: int = -1;

    def add_block -> basicblock {
        b = basicblock(id=self.next_block_id, instrs=[]);
        self.next_block_id = self.next_block_id + 1;
        self.blocks.append(b);
        return b;
    }

    # Allocate a block id without placing it in the layout. The block is laid out
    # later, at its first use() (CPython NEW_JUMP_TARGET_LABEL vs USE_LABEL). Lets
    # codegen allocate a forward target (e.g. a MatchOr shared end) up front and
    # place it after the intervening bodies, so layout order != allocation order.
    def add_deferred_block -> basicblock {
        b = basicblock(id=self.next_block_id, instrs=[], placed=False);
        self.next_block_id = self.next_block_id + 1;
        return b;
    }

    # Const dedup by value (tp_hashkey collapses numeric/value equality the same
    # way CPython's const table dedups). Append-first-seen preserves CPython's
    # deterministic ordering.
    def add_const(c: PyObj) -> int {
        key = c.tp_hashkey();
        i = 0;
        while i < len(self.consts) {
            if self.consts[i].tp_hashkey() == key {
                return i;
            }
            i = i + 1;
        }
        self.consts.append(c);
        return len(self.consts) - 1;
    }

    def add_name(n: str) -> int {
        i = 0;
        while i < len(self.names) {
            if self.names[i] == n {
                return i;
            }
            i = i + 1;
        }
        self.names.append(n);
        return len(self.names) - 1;
    }
}

# Shared instruction sizing (assembler linetable + flowgraph jump resolution).
def extended_arg_count(oparg: int) -> int {
    n = 0;
    if oparg > 0xFFFFFF {
        n = n + 1;
    }
    if oparg > 0xFFFF {
        n = n + 1;
    }
    if oparg > 0xFF {
        n = n + 1;
    }
    return n;
}

def instr_size_codeunits(ins: cinstr) -> int {
    return extended_arg_count(ins.oparg) + 1 + opcode_cache_count(ins.opcode);
}
