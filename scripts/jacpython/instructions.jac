"""JacPython's instruction definitions: every instruction, the ops it is made
of, the stack each op reads and writes, and the specialization families.

The op bodies are plain Jac definitions in
jac/jaclang/runtime/python/interpreter/ops.jac, named after the op. This table
says how an op sits on the value stack; gen_eval.jac turns both into the
interpreter's instruction handlers.

Stack effects are written `inputs -- outputs`, bottom of the stack first:
- `name[count]` is an array of `count` items (a C expression of oparg); the op
  receives a pointer to its first item.
- `name/N` before the inputs reads an N-unit inline cache entry and passes it
  to the op under that name.
- an input written again among the outputs at the same depth (`left, unused --
  left, unused`) passes through untouched; `unused` is never loaded.
- any other input is consumed. The op only borrows it, and the handler closes
  it after the op succeeds; on an error it stays on the stack for the unwinder.
- `name!` hands the input to the op, which owns it from then on (it closes or
  stores it, also when it fails). Owned inputs are the topmost ones.

The definition's own signature says how the op ends: returning `u64` makes the
single output; `bool` is a guard that deoptimizes on False; `i64` advances
next_instr by the value; `ptr[u8]` (with `resume`) switches to the returned
frame; `i32` is a status, returned by name (the generator reads the body for
the names it returns and emits only those exits):
  ST_OK (0) continue;
  ST_ERROR (1) error (borrowed inputs stay on the stack for the unwinder, owned ones are
    gone);
  ST_DEOPT (2) deoptimize to the family head (only before any stack change);
  ST_REDISPATCH (3) dispatch this instruction again, after specializing it (same condition);
  ST_UNWIND (4) like ST_ERROR, but go to exception_unwind without recording a traceback entry;
  ST_INLINED (5) the op has pushed a frame that took every input (tstate's current frame);
    continue there at its start;
  ST_ERROR_TAKEN (6) error after the op took every input;
  ST_EXHAUSTED (7) the iterator is exhausted: skip past the loop (oparg + 1), with the inputs
    left as they were;
  ST_RESUME_AT (8) continue at frame.instr_ptr (a monitoring callback moved it), inputs left
    as they were.
An op with `error=True` reports an error with a 0 output. Outputs an op does
not return are written through `name: ptr[u64]` parameters. Other parameters
are bound by name: frame, tstate, oparg, this_instr, next_instr, and caches.

A frame switch (`_PUSH_FRAME`, returns, yields) takes its inputs as owned and
has no outputs: the op links the frame it returns as tstate's current frame
and pushes any result onto that frame's stack itself. `resume` says where the
new frame continues: "start" (its instr_ptr), "return" (instr_ptr plus its
return_offset) or an offset from instr_ptr.

A `raw` instruction has no ops: its handler is written by hand in ops.jac as
`_TAIL_CALL_<NAME>`, for the few that switch frames or leave the interpreter.

An op escapes when it can run arbitrary code (a call, a decref, an
allocation). Before it runs, the frame's stack pointer is published so the
garbage collector sees exactly the live stack. `escapes=False` skips that.
"""

obj Op {
    has name: str,
        stack: str,
        inst: bool = False,
        raw: bool = False,
        resume: str = "",
        escapes: bool = True,
        error: bool = False;
}

obj Macro {
    has name: str,
        parts: str;
}

obj Family {
    has head: str,
        members: list[str];
}

glob OPS: list[Op] = [
         Op("NOP", "--", inst=True, escapes=False),
         Op("NOT_TAKEN", "--", inst=True, escapes=False),
         Op("POP_TOP", "value --", inst=True, escapes=False),
         Op("PUSH_NULL", "-- res", inst=True, escapes=False),
         Op("LOAD_FAST", "-- value", inst=True, escapes=False),
         Op("LOAD_FAST_BORROW", "-- value", inst=True, escapes=False),
         Op("LOAD_FAST_AND_CLEAR", "-- value", inst=True, escapes=False),
         Op("LOAD_FAST_LOAD_FAST", "-- value1, value2", inst=True, escapes=False),
         Op(
             "LOAD_FAST_BORROW_LOAD_FAST_BORROW",
             "-- value1, value2",
             inst=True,
             escapes=False
         ),
         Op("LOAD_CONST", "-- value", inst=True, escapes=False),
         Op("LOAD_CONST_MORTAL", "-- value", inst=True, escapes=False),
         Op("LOAD_CONST_IMMORTAL", "-- value", inst=True, escapes=False),
         Op("LOAD_SMALL_INT", "-- value", inst=True, escapes=False),
         Op("STORE_FAST", "value! --", inst=True),
         Op("STORE_FAST_LOAD_FAST", "value1! -- value2", inst=True),
         Op("STORE_FAST_STORE_FAST", "value2!, value1! --", inst=True),
         Op("COPY", "values[oparg] -- values[oparg], top", inst=True, escapes=False),
         Op("SWAP", "values[oparg] -- values[oparg]", inst=True, escapes=False),
         Op("UNARY_NOT", "value! -- res", inst=True, escapes=False),
         Op("JUMP_FORWARD", "--", inst=True, escapes=False),
         Op("_GUARD_TOS_INT", "value -- value"),
         Op("_GUARD_NOS_INT", "left, unused -- left, unused"),
         Op("_BINARY_OP_ADD_INT", "left!, right! -- res", error=True),
         Op("_BINARY_OP_SUBTRACT_INT", "left!, right! -- res", error=True),
         Op("_BINARY_OP_MULTIPLY_INT", "left!, right! -- res", error=True),
         Op("_IS_NONE", "value -- b", escapes=False),
         Op("_POP_JUMP_IF_FALSE", "cond! --", escapes=False),
         Op("_POP_JUMP_IF_TRUE", "cond! --", escapes=False),
         Op("_CHECK_PEP_523", "--"),
         Op("_PUSH_FRAME", "new_frame! --", resume="start"),
         Op("_SAVE_RETURN_OFFSET", "--", escapes=False),
         Op("_CHECK_PERIODIC", "--"),
         Op("_CHECK_PERIODIC_IF_NOT_YIELD_FROM", "--"),
         Op("_PUSH_NULL_CONDITIONAL", "-- null[oparg & 1]", escapes=False),
         Op("_GUARD_TYPE_VERSION", "type_version/2, owner -- owner"),
         Op("_GUARD_TOS_LIST", "tos -- tos")
     ],
     MACROS: list[Macro] = [
         Macro(
             "BINARY_OP_MULTIPLY_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_INT + unused/5 + _BINARY_OP_MULTIPLY_INT"
         ),
         Macro(
             "BINARY_OP_ADD_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_INT + unused/5 + _BINARY_OP_ADD_INT"
         ),
         Macro(
             "BINARY_OP_SUBTRACT_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_INT + unused/5 + _BINARY_OP_SUBTRACT_INT"
         ),
         Macro("POP_JUMP_IF_TRUE", "unused/1 + _POP_JUMP_IF_TRUE"),
         Macro("POP_JUMP_IF_FALSE", "unused/1 + _POP_JUMP_IF_FALSE"),
         Macro("POP_JUMP_IF_NONE", "unused/1 + _IS_NONE + _POP_JUMP_IF_TRUE"),
         Macro("POP_JUMP_IF_NOT_NONE", "unused/1 + _IS_NONE + _POP_JUMP_IF_FALSE")
     ],
     FAMILIES: list[Family] = [
         Family(
             "BINARY_OP",
             ["BINARY_OP_MULTIPLY_INT", "BINARY_OP_ADD_INT", "BINARY_OP_SUBTRACT_INT"]
         ),
         Family("LOAD_CONST", ["LOAD_CONST_MORTAL", "LOAD_CONST_IMMORTAL"])
     ];
