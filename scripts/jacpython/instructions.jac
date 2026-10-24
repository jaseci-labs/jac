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
         Op("_GUARD_TOS_LIST", "tos -- tos"),
         Op("LOAD_FAST_CHECK", "-- value", inst=True, error=True),
         Op("DELETE_FAST", "--", inst=True),
         Op("LOAD_COMMON_CONSTANT", "-- value", inst=True, escapes=False),
         Op("STORE_NAME", "v --", inst=True),
         Op("DELETE_NAME", "--", inst=True),
         Op("STORE_GLOBAL", "v --", inst=True),
         Op("DELETE_GLOBAL", "--", inst=True),
         Op("LOAD_LOCALS", "-- locals", inst=True, error=True),
         Op(
             "LOAD_FROM_DICT_OR_GLOBALS",
             "mod_or_class_dict! -- v",
             inst=True,
             error=True
         ),
         Op("LOAD_NAME", "-- v", inst=True, error=True),
         Op("_SPECIALIZE_LOAD_GLOBAL", "counter/1 --"),
         Op("_LOAD_GLOBAL", "-- res"),
         Op("_GUARD_GLOBALS_VERSION", "version/1 --", escapes=False),
         Op(
             "_LOAD_GLOBAL_MODULE", "version/1, unused/1, index/1 -- res", escapes=False
         ),
         Op("_LOAD_GLOBAL_BUILTINS", "version/1, index/1 -- res", escapes=False),
         Op("MAKE_CELL", "--", inst=True),
         Op("DELETE_DEREF", "--", inst=True),
         Op("LOAD_FROM_DICT_OR_DEREF", "class_dict_st -- value", inst=True, error=True),
         Op("LOAD_DEREF", "-- value", inst=True, error=True),
         Op("STORE_DEREF", "v! --", inst=True),
         Op("COPY_FREE_VARS", "--", inst=True, escapes=False),
         Op("SETUP_ANNOTATIONS", "--", inst=True),
         Op("IMPORT_NAME", "level, fromlist -- res", inst=True, error=True),
         Op("IMPORT_FROM", "from_ -- from_, res", inst=True, error=True),
         Op(
             "BUILD_TUPLE",
             "values[oparg]! -- tup",
             inst=True,
             escapes=False,
             error=True
         ),
         Op("BUILD_LIST", "values[oparg]! -- lst", inst=True, error=True),
         Op("BUILD_SET", "values[oparg]! -- st", inst=True, error=True),
         Op("BUILD_MAP", "values[oparg*2] -- dct", inst=True, error=True),
         Op(
             "BUILD_STRING",
             "pieces[oparg] -- text",
             inst=True,
             escapes=False,
             error=True
         ),
         Op(
             "BUILD_SLICE", "args[oparg] -- slice", inst=True, escapes=False, error=True
         ),
         Op(
             "BUILD_INTERPOLATION",
             "value, text, fmt[oparg & 1] -- interpolation",
             inst=True,
             error=True
         ),
         Op(
             "BUILD_TEMPLATE",
             "strings, interpolations -- template",
             inst=True,
             error=True
         ),
         Op("CONVERT_VALUE", "value -- result", inst=True, error=True),
         Op("FORMAT_SIMPLE", "value! -- res", inst=True, error=True),
         Op("FORMAT_WITH_SPEC", "value, fmt_spec -- res", inst=True, error=True),
         Op("GET_LEN", "value -- value, length", inst=True, error=True),
         Op(
             "LIST_APPEND",
             "lst, unused[oparg-1], v! -- lst, unused[oparg-1]",
             inst=True,
             escapes=False
         ),
         Op(
             "LIST_EXTEND",
             "lst, unused[oparg-1], iterable -- lst, unused[oparg-1]",
             inst=True
         ),
         Op("SET_ADD", "st, unused[oparg-1], v! -- st, unused[oparg-1]", inst=True),
         Op(
             "SET_UPDATE",
             "st, unused[oparg-1], iterable -- st, unused[oparg-1]",
             inst=True
         ),
         Op(
             "DICT_UPDATE",
             "dct, unused[oparg - 1], update -- dct, unused[oparg - 1]",
             inst=True
         ),
         Op(
             "DICT_MERGE",
             "callable, unused, unused, dct, unused[oparg - 1], update -- callable, unused, unused, dct, unused[oparg - 1]",
             inst=True
         ),
         Op(
             "MAP_ADD",
             "dct, unused[oparg - 1], key!, value! -- dct, unused[oparg - 1]",
             inst=True
         ),
         Op("MATCH_CLASS", "subject, type, names -- attrs", inst=True, error=True),
         Op(
             "MATCH_KEYS",
             "subject, keys -- subject, keys, values_or_none",
             inst=True,
             error=True
         ),
         Op("MATCH_MAPPING", "subject -- subject, res", inst=True, escapes=False),
         Op("MATCH_SEQUENCE", "subject -- subject, res", inst=True, escapes=False),
         Op(
             "UNPACK_EX", "seq! -- output[(oparg & 0xFF) + (oparg >> 8) + 1]", inst=True
         ),
         Op("_SPECIALIZE_UNPACK_SEQUENCE", "counter/1, seq -- seq"),
         Op("_UNPACK_SEQUENCE", "seq! -- output[oparg]"),
         Op("_GUARD_TOS_TUPLE", "tos -- tos", escapes=False),
         Op("_UNPACK_SEQUENCE_TWO_TUPLE", "seq -- val1, val0", escapes=False),
         Op("_UNPACK_SEQUENCE_TUPLE", "seq -- values[oparg]", escapes=False),
         Op("_UNPACK_SEQUENCE_LIST", "seq -- values[oparg]", escapes=False),
         Op("_GUARD_NOS_NULL", "null, unused -- null, unused", escapes=False),
         Op(
             "_GUARD_CALLABLE_TYPE_1",
             "callable, unused, unused -- callable, unused, unused",
             escapes=False
         ),
         Op(
             "_GUARD_CALLABLE_STR_1",
             "callable, unused, unused -- callable, unused, unused",
             escapes=False
         ),
         Op(
             "_GUARD_CALLABLE_TUPLE_1",
             "callable, unused, unused -- callable, unused, unused",
             escapes=False
         ),
         Op(
             "_GUARD_CALLABLE_LEN",
             "callable, unused, unused -- callable, unused, unused",
             escapes=False
         ),
         Op("_CALL_TYPE_1", "callable!, null!, arg! -- res"),
         Op("_CALL_STR_1", "callable!, null!, arg! -- res", error=True),
         Op("_CALL_TUPLE_1", "callable!, null!, arg! -- res", error=True),
         Op("_CALL_LEN", "callable, null, arg -- res", error=True),
         Op("_CALL_BUILTIN_CLASS", "callable, self_or_null, args[oparg] -- res"),
         Op("_CALL_BUILTIN_O", "callable, self_or_null, args[oparg] -- res"),
         Op("_CALL_BUILTIN_FAST", "callable, self_or_null, args[oparg] -- res"),
         Op(
             "_CALL_BUILTIN_FAST_WITH_KEYWORDS",
             "callable, self_or_null, args[oparg] -- res"
         ),
         Op(
             "CALL_ISINSTANCE",
             "unused/1, unused/2, callable, self_or_null, args[oparg] -- res",
             inst=True
         ),
         Op("_CALL_LIST_APPEND", "callable!, self_!, arg! --"),
         Op("_SKIP_POP_TOP", "--", escapes=False),
         Op("_CALL_METHOD_DESCRIPTOR_O", "callable, self_or_null, args[oparg] -- res"),
         Op(
             "_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS",
             "callable, self_or_null, args[oparg] -- res"
         ),
         Op(
             "_CALL_METHOD_DESCRIPTOR_NOARGS",
             "callable, self_or_null, args[oparg] -- res"
         ),
         Op(
             "_CALL_METHOD_DESCRIPTOR_FAST",
             "callable, self_or_null, args[oparg] -- res"
         ),
         Op("CALL_INTRINSIC_1", "value -- res", inst=True, error=True),
         Op("CALL_INTRINSIC_2", "value2_st, value1_st -- res", inst=True, error=True),
         Op("MAKE_FUNCTION", "codeobj_st -- func", inst=True, error=True),
         Op(
             "SET_FUNCTION_ATTRIBUTE",
             "attr_st!, func_in! -- func_out",
             inst=True,
             error=True
         ),
         Op("LOAD_BUILD_CLASS", "-- bc", inst=True, error=True),
         Op(
             "_SPECIALIZE_CALL",
             "counter/1, callable, self_or_null, unused[oparg] -- callable, self_or_null, unused[oparg]"
         ),
         Op(
             "_MAYBE_EXPAND_METHOD",
             "callable_self[2], unused[oparg] -- callable_self[2], unused[oparg]"
         ),
         Op("_DO_CALL", "callable, self_or_null, args[oparg] -- res"),
         Op("_DO_CALL_INSTRUMENTED", "callable, self_or_null, args[oparg] -- res"),
         Op(
             "_CHECK_FUNCTION_VERSION",
             "func_version/2, callable, unused, unused[oparg] -- callable, unused, unused[oparg]",
             escapes=False
         ),
         Op(
             "_CHECK_FUNCTION_EXACT_ARGS",
             "callable, self_or_null, unused[oparg] -- callable, self_or_null, unused[oparg]",
             escapes=False
         ),
         Op(
             "_CHECK_STACK_SPACE",
             "callable, unused, unused[oparg] -- callable, unused, unused[oparg]",
             escapes=False
         ),
         Op("_CHECK_RECURSION_REMAINING", "--", escapes=False),
         Op(
             "_INIT_CALL_PY_EXACT_ARGS",
             "callable!, self_or_null!, args[oparg]! -- new_frame",
             escapes=False
         ),
         Op(
             "_CHECK_METHOD_VERSION",
             "func_version/2, callable, null, unused[oparg] -- callable, null, unused[oparg]",
             escapes=False
         ),
         Op(
             "_CHECK_METHOD_EXACT_ARGS",
             "callable, unused, unused[oparg] -- callable, unused, unused[oparg]",
             escapes=False
         ),
         Op(
             "_CHECK_METHOD_STACK_SPACE",
             "callable, unused, unused[oparg] -- callable, unused, unused[oparg]",
             escapes=False
         ),
         Op(
             "_INIT_CALL_BOUND_METHOD_EXACT_ARGS",
             "callable_self[2], unused[oparg] -- callable_self[2], unused[oparg]"
         ),
         Op(
             "_EXPAND_METHOD",
             "callable_self[2], unused[oparg] -- callable_self[2], unused[oparg]"
         ),
         Op(
             "_PY_FRAME_GENERAL",
             "callable!, self_or_null!, args[oparg]! -- new_frame",
             error=True
         ),
         Op(
             "_CHECK_IS_NOT_PY_CALLABLE",
             "callable, unused, unused[oparg] -- callable, unused, unused[oparg]",
             escapes=False
         ),
         Op(
             "_CALL_NON_PY_GENERAL",
             "callable, self_or_null, args[oparg] -- res",
             error=True
         ),
         Op(
             "_CHECK_AND_ALLOCATE_OBJECT",
             "type_version/2, callable_self[2], unused[oparg] -- callable_self[2], unused[oparg]"
         ),
         Op(
             "_CREATE_INIT_FRAME",
             "init_fn!, self_!, args[oparg]! -- init_frame",
             error=True
         ),
         Op("EXIT_INIT_CHECK", "should_be_none! --", inst=True),
         Op(
             "_SPECIALIZE_CALL_KW",
             "counter/1, callable, self_or_null, unused[oparg], unused -- callable, self_or_null, unused[oparg], unused"
         ),
         Op(
             "_MAYBE_EXPAND_METHOD_KW",
             "callable_self[2], unused[oparg], unused -- callable_self[2], unused[oparg], unused"
         ),
         Op("_DO_CALL_KW", "callable, self_or_null, args[oparg], kwnames -- res"),
         Op(
             "_DO_CALL_KW_INSTRUMENTED",
             "callable, self_or_null, args[oparg], kwnames -- res"
         ),
         Op(
             "_CHECK_FUNCTION_VERSION_KW",
             "func_version/2, callable, unused, unused[oparg], unused -- callable, unused, unused[oparg], unused",
             escapes=False
         ),
         Op(
             "_PY_FRAME_KW",
             "callable!, self_or_null!, args[oparg]!, kwnames! -- new_frame",
             error=True
         ),
         Op(
             "_CHECK_METHOD_VERSION_KW",
             "func_version/2, callable, null, unused[oparg], unused -- callable, null, unused[oparg], unused",
             escapes=False
         ),
         Op(
             "_EXPAND_METHOD_KW",
             "callable_self[2], unused[oparg], unused -- callable_self[2], unused[oparg], unused"
         ),
         Op(
             "_CHECK_IS_NOT_PY_CALLABLE_KW",
             "callable, unused, unused[oparg], unused -- callable, unused, unused[oparg], unused",
             escapes=False
         ),
         Op(
             "_CALL_KW_NON_PY",
             "callable, self_or_null, args[oparg], kwnames -- res",
             error=True
         ),
         Op(
             "_MAKE_CALLARGS_A_TUPLE",
             "func, unused, callargs[1], unused -- func, unused, callargs[1], unused"
         ),
         Op("_DO_CALL_FUNCTION_EX", "func_st, null, callargs_st, kwargs_st -- result"),
         Op(
             "_DO_CALL_FUNCTION_EX_INSTRUMENTED",
             "func_st, null, callargs_st, kwargs_st -- result"
         ),
         Op("RETURN_VALUE", "retval! --", inst=True, resume="return"),
         Op("YIELD_VALUE", "retval! --", inst=True, resume="2"),
         Op("_MAKE_GENERATOR", "-- gen", error=True),
         Op("_RETURN_GENERATOR", "gen! --", resume="return"),
         Op("CACHE", "--", inst=True, raw=True),
         Op("RESERVED", "--", inst=True, raw=True),
         Op("ENTER_EXECUTOR", "--", inst=True, raw=True),
         Op("EXTENDED_ARG", "--", inst=True, raw=True),
         Op("INTERPRETER_EXIT", "retval --", inst=True, raw=True),
         Op(
             "CHECK_EG_MATCH", "exc_value_st, match_type_st -- rest, matched", inst=True
         ),
         Op("CHECK_EXC_MATCH", "left, right -- left, b", inst=True, error=True),
         Op("POP_EXCEPT", "exc_value! --", inst=True),
         Op("PUSH_EXC_INFO", "exc! -- prev_exc, new_exc", inst=True, escapes=False),
         Op("RAISE_VARARGS", "args[oparg]! --", inst=True),
         Op("RERAISE", "values[oparg], exc_st! -- values[oparg]", inst=True),
         Op(
             "WITH_EXCEPT_START",
             "exit_func, exit_self, unused, unused, val -- exit_func, exit_self, unused, unused, val, res",
             inst=True,
             error=True
         ),
         Op("JUMP_BACKWARD_NO_INTERRUPT", "--", inst=True, escapes=False),
         Op("RESUME_CHECK", "--", inst=True, escapes=False),
         Op("_SPECIALIZE_JUMP_BACKWARD", "--", escapes=False),
         Op("_JIT", "--", escapes=False),
         Op("_LOAD_BYTECODE", "--", escapes=False),
         Op("_MAYBE_INSTRUMENT", "--"),
         Op("_QUICKEN_RESUME", "--", escapes=False),
         Op("UNARY_NEGATIVE", "value -- res", inst=True, error=True),
         Op("UNARY_INVERT", "value -- res", inst=True, error=True),
         Op("_SPECIALIZE_TO_BOOL", "counter/1, value -- value"),
         Op("_TO_BOOL", "value -- res", error=True),
         Op("TO_BOOL_BOOL", "unused/1, unused/2, value -- value", inst=True),
         Op(
             "TO_BOOL_INT", "unused/1, unused/2, value -- res", inst=True, escapes=False
         ),
         Op(
             "TO_BOOL_NONE",
             "unused/1, unused/2, value! -- res",
             inst=True,
             escapes=False
         ),
         Op("_TO_BOOL_LIST", "value -- res", escapes=False),
         Op("_TO_BOOL_STR", "value -- res", escapes=False),
         Op("_REPLACE_WITH_TRUE", "value -- res", escapes=False),
         Op("_GUARD_NOS_LIST", "nos, unused -- nos, unused"),
         Op("_GUARD_TOS_SLICE", "tos -- tos"),
         Op("_GUARD_NOS_UNICODE", "nos, unused -- nos, unused"),
         Op("_GUARD_TOS_UNICODE", "value -- value"),
         Op("_GUARD_NOS_FLOAT", "left, unused -- left, unused"),
         Op("_GUARD_TOS_FLOAT", "value -- value"),
         Op("_GUARD_NOS_TUPLE", "nos, unused -- nos, unused"),
         Op("_GUARD_NOS_DICT", "nos, unused -- nos, unused"),
         Op("_GUARD_TOS_DICT", "tos -- tos"),
         Op("_GUARD_TOS_ANY_SET", "tos -- tos"),
         Op("_BINARY_OP_MULTIPLY_FLOAT", "left!, right! -- res", error=True),
         Op("_BINARY_OP_ADD_FLOAT", "left!, right! -- res", error=True),
         Op("_BINARY_OP_SUBTRACT_FLOAT", "left!, right! -- res", error=True),
         Op("_BINARY_OP_ADD_UNICODE", "left!, right! -- res", error=True),
         Op("_BINARY_OP_INPLACE_ADD_UNICODE", "left!, right! --"),
         Op("_SKIP_STORE_FAST", "--", escapes=False),
         Op("_GUARD_BINARY_OP_EXTEND", "descr/4, left, right -- left, right"),
         Op("_BINARY_OP_EXTEND", "left, right -- res", error=True),
         Op(
             "_SPECIALIZE_BINARY_SLICE",
             "container, start, stop -- container, start, stop"
         ),
         Op("_BINARY_SLICE", "container, start!, stop! -- res", error=True),
         Op(
             "_SPECIALIZE_STORE_SLICE",
             "v, container, start, stop -- v, container, start, stop"
         ),
         Op("_STORE_SLICE", "v, container, start!, stop! --"),
         Op("_BINARY_OP_SUBSCR_LIST_INT", "list_st, sub_st -- res", escapes=False),
         Op("_BINARY_OP_SUBSCR_LIST_SLICE", "list_st, sub_st -- res", error=True),
         Op("_BINARY_OP_SUBSCR_STR_INT", "str_st!, sub_st! -- res"),
         Op("_BINARY_OP_SUBSCR_TUPLE_INT", "tuple_st, sub_st! -- res", escapes=False),
         Op("_BINARY_OP_SUBSCR_DICT", "dict_st, sub_st -- res", error=True),
         Op("_BINARY_OP_SUBSCR_CHECK_FUNC", "container, unused -- container, unused"),
         Op(
             "_BINARY_OP_SUBSCR_INIT_CALL",
             "container!, sub! -- new_frame",
             escapes=False
         ),
         Op("_SPECIALIZE_STORE_SUBSCR", "counter/1, container, sub -- container, sub"),
         Op("_STORE_SUBSCR", "v, container, sub --"),
         Op("_STORE_SUBSCR_LIST_INT", "value!, list_st!, sub_st! --"),
         Op("_STORE_SUBSCR_DICT", "value!, dict_st!, sub! --"),
         Op("DELETE_SUBSCR", "container, sub --", inst=True),
         Op("_SPECIALIZE_COMPARE_OP", "counter/1, left, right -- left, right"),
         Op("_COMPARE_OP", "left!, right! -- res", error=True),
         Op("_COMPARE_OP_FLOAT", "left!, right! -- res", escapes=False),
         Op("_COMPARE_OP_INT", "left!, right! -- res", escapes=False),
         Op("_COMPARE_OP_STR", "left!, right! -- res", escapes=False),
         Op("IS_OP", "left, right -- b", inst=True, escapes=False),
         Op("_SPECIALIZE_CONTAINS_OP", "counter/1, left, right -- left, right"),
         Op("_CONTAINS_OP", "left, right -- b", error=True),
         Op("_CONTAINS_OP_SET", "left, right -- b", error=True),
         Op("_CONTAINS_OP_DICT", "left, right -- b", error=True),
         Op("_SPECIALIZE_BINARY_OP", "counter/1, lhs, rhs -- lhs, rhs"),
         Op("_BINARY_OP", "lhs, rhs -- res", error=True),
         Op("_MONITOR_RESUME", "--"),
         Op("_RETURN_VALUE_EVENT", "val -- val"),
         Op("_YIELD_VALUE_EVENT", "val -- val"),
         Op(
             "_MONITOR_CALL",
             "func, maybe_self, args[oparg] -- func, maybe_self, args[oparg]"
         ),
         Op(
             "_MONITOR_CALL_KW",
             "callable, self_or_null, args[oparg], unused -- callable, self_or_null, args[oparg], unused"
         ),
         Op("INSTRUMENTED_END_SEND", "receiver, value! -- val", inst=True, error=True),
         Op("INSTRUMENTED_END_FOR", "receiver, value -- receiver", inst=True, raw=True),
         Op("INSTRUMENTED_POP_ITER", "iter --", inst=True, raw=True),
         Op(
             "INSTRUMENTED_FOR_ITER",
             "unused/1, iter -- iter, next",
             inst=True,
             raw=True
         ),
         Op(
             "INSTRUMENTED_END_ASYNC_FOR",
             "awaitable_st, exc_st --",
             inst=True,
             raw=True
         ),
         Op("INSTRUMENTED_LINE", "--", inst=True, raw=True),
         Op("INSTRUMENTED_INSTRUCTION", "--", inst=True, raw=True),
         Op("INSTRUMENTED_JUMP_FORWARD", "--", inst=True, raw=True),
         Op("INSTRUMENTED_JUMP_BACKWARD", "unused/1 --", inst=True, raw=True),
         Op("INSTRUMENTED_NOT_TAKEN", "--", inst=True, raw=True),
         Op("INSTRUMENTED_POP_JUMP_IF_TRUE", "unused/1, cond --", inst=True, raw=True),
         Op("INSTRUMENTED_POP_JUMP_IF_FALSE", "unused/1, cond --", inst=True, raw=True),
         Op("INSTRUMENTED_POP_JUMP_IF_NONE", "unused/1, value --", inst=True, raw=True),
         Op(
             "INSTRUMENTED_POP_JUMP_IF_NOT_NONE",
             "unused/1, value --",
             inst=True,
             raw=True
         ),
         Op("END_FOR", "value --", inst=True, raw=True),
         Op("END_SEND", "receiver, value! -- val", inst=True, escapes=False),
         Op("GET_ITER", "iterable -- iter_", inst=True, error=True),
         Op("GET_YIELD_FROM_ITER", "iterable -- iter_", inst=True, error=True),
         Op("GET_AITER", "obj_ -- iter_", inst=True, error=True),
         Op("GET_ANEXT", "aiter -- aiter, awaitable", inst=True, error=True),
         Op("GET_AWAITABLE", "iterable -- iter_", inst=True, error=True),
         Op("_END_ASYNC_FOR", "awaitable_st, exc_st --"),
         Op(
             "CLEANUP_THROW",
             "sub_iter, last_sent_val, exc_value_st -- none, value",
             inst=True
         ),
         Op("_SPECIALIZE_FOR_ITER", "counter/1, iter_ -- iter_"),
         Op("_FOR_ITER", "iter_ -- iter_, next_"),
         Op("_ITER_CHECK_LIST", "iter_ -- iter_", escapes=False),
         Op("_ITER_JUMP_LIST", "iter_ -- iter_"),
         Op("_ITER_NEXT_LIST", "iter_ -- iter_, next_", escapes=False),
         Op("_ITER_CHECK_TUPLE", "iter_ -- iter_", escapes=False),
         Op("_ITER_JUMP_TUPLE", "iter_ -- iter_"),
         Op("_ITER_NEXT_TUPLE", "iter_ -- iter_, next_", escapes=False),
         Op("_ITER_CHECK_RANGE", "iter_ -- iter_", escapes=False),
         Op("_ITER_JUMP_RANGE", "iter_ -- iter_", escapes=False),
         Op("_ITER_NEXT_RANGE", "iter_ -- iter_, next_", error=True),
         Op("_FOR_ITER_GEN_FRAME", "iter_ -- iter_, gen_frame", escapes=False),
         Op("_SPECIALIZE_SEND", "counter/1, receiver, unused -- receiver, unused"),
         Op("_SEND", "v! -- retval"),
         Op("_SEND_GEN_FRAME", "receiver, v! -- receiver, gen_frame", escapes=False),
         Op("_SPECIALIZE_LOAD_ATTR", "counter/1, owner -- owner"),
         Op("_LOAD_ATTR", "owner! -- attr, self_or_null[oparg&1]", error=True),
         Op("_CHECK_MANAGED_OBJECT_HAS_VALUES", "owner -- owner"),
         Op("_LOAD_ATTR_INSTANCE_VALUE", "offset/1, owner -- attr", escapes=False),
         Op(
             "_LOAD_ATTR_MODULE",
             "dict_version/2, index/1, owner -- attr",
             escapes=False
         ),
         Op("_LOAD_ATTR_WITH_HINT", "hint/1, owner -- attr", escapes=False),
         Op("_LOAD_ATTR_SLOT", "index/1, owner -- attr", escapes=False),
         Op("_CHECK_ATTR_CLASS", "type_version/2, owner -- owner"),
         Op("_LOAD_ATTR_CLASS", "descr/4, owner -- attr", escapes=False),
         Op("_LOAD_ATTR_PROPERTY_FRAME", "fget/4, owner! -- new_frame", escapes=False),
         Op(
             "LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN",
             "unused/1, type_version/2, func_version/2, getattribute/4, owner! --",
             inst=True,
             escapes=False
         ),
         Op("_GUARD_DORV_VALUES_INST_ATTR_FROM_DICT", "owner -- owner"),
         Op("_GUARD_KEYS_VERSION", "keys_version/2, owner -- owner"),
         Op(
             "_LOAD_ATTR_METHOD_WITH_VALUES",
             "descr/4, owner! -- attr, self_",
             escapes=False
         ),
         Op(
             "_LOAD_ATTR_METHOD_NO_DICT",
             "descr/4, owner! -- attr, self_",
             escapes=False
         ),
         Op("_CHECK_ATTR_METHOD_LAZY_DICT", "dictoffset/1, owner -- owner"),
         Op(
             "_LOAD_ATTR_METHOD_LAZY_DICT",
             "descr/4, owner! -- attr, self_",
             escapes=False
         ),
         Op(
             "_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES",
             "descr/4, owner -- attr",
             escapes=False
         ),
         Op(
             "_LOAD_ATTR_NONDESCRIPTOR_NO_DICT", "descr/4, owner -- attr", escapes=False
         ),
         Op(
             "_SPECIALIZE_LOAD_SUPER_ATTR",
             "counter/1, global_super_st, class_st, unused -- global_super_st, class_st, unused"
         ),
         Op(
             "_LOAD_SUPER_ATTR",
             "global_super_st, class_st, self_st -- attr",
             error=True
         ),
         Op(
             "_LOAD_SUPER_ATTR_INSTRUMENTED",
             "global_super_st, class_st, self_st -- attr",
             error=True
         ),
         Op(
             "LOAD_SUPER_ATTR_ATTR",
             "unused/1, global_super_st, class_st, self_st -- attr_st",
             inst=True
         ),
         Op(
             "LOAD_SUPER_ATTR_METHOD",
             "unused/1, global_super_st, class_st, self_st! -- attr, self_or_null",
             inst=True
         ),
         Op("_INSERT_NULL", "self_! -- method_and_self[2]", escapes=False),
         Op("_LOAD_SPECIAL", "method_and_self[2] -- method_and_self[2]"),
         Op("_SPECIALIZE_STORE_ATTR", "counter/1, owner -- owner"),
         Op("_STORE_ATTR", "v, owner --"),
         Op("DELETE_ATTR", "owner --", inst=True),
         Op("_GUARD_TYPE_VERSION_AND_LOCK", "type_version/2, owner -- owner"),
         Op("_GUARD_DORV_NO_DICT", "owner -- owner"),
         Op("_STORE_ATTR_INSTANCE_VALUE", "offset/1, value!, owner! --"),
         Op("_STORE_ATTR_WITH_HINT", "hint/1, value!, owner! --"),
         Op("_STORE_ATTR_SLOT", "index/1, value!, owner! --")
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
         Macro("POP_JUMP_IF_NOT_NONE", "unused/1 + _IS_NONE + _POP_JUMP_IF_FALSE"),
         Macro(
             "LOAD_GLOBAL",
             "_SPECIALIZE_LOAD_GLOBAL + unused/3 + _LOAD_GLOBAL + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_GLOBAL_MODULE",
             "unused/1 + _LOAD_GLOBAL_MODULE + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_GLOBAL_BUILTIN",
             "unused/1 + _GUARD_GLOBALS_VERSION + _LOAD_GLOBAL_BUILTINS + _PUSH_NULL_CONDITIONAL"
         ),
         Macro("UNPACK_SEQUENCE", "_SPECIALIZE_UNPACK_SEQUENCE + _UNPACK_SEQUENCE"),
         Macro(
             "UNPACK_SEQUENCE_TWO_TUPLE",
             "_GUARD_TOS_TUPLE + unused/1 + _UNPACK_SEQUENCE_TWO_TUPLE"
         ),
         Macro(
             "UNPACK_SEQUENCE_TUPLE",
             "_GUARD_TOS_TUPLE + unused/1 + _UNPACK_SEQUENCE_TUPLE"
         ),
         Macro(
             "UNPACK_SEQUENCE_LIST",
             "_GUARD_TOS_LIST + unused/1 + _UNPACK_SEQUENCE_LIST"
         ),
         Macro(
             "CALL_TYPE_1",
             "unused/1 + unused/2 + _GUARD_NOS_NULL + _GUARD_CALLABLE_TYPE_1 + _CALL_TYPE_1"
         ),
         Macro(
             "CALL_STR_1",
             "unused/1 + unused/2 + _GUARD_NOS_NULL + _GUARD_CALLABLE_STR_1 + _CALL_STR_1 + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_TUPLE_1",
             "unused/1 + unused/2 + _GUARD_NOS_NULL + _GUARD_CALLABLE_TUPLE_1 + _CALL_TUPLE_1 + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_BUILTIN_CLASS",
             "unused/1 + unused/2 + _CALL_BUILTIN_CLASS + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_BUILTIN_O", "unused/1 + unused/2 + _CALL_BUILTIN_O + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_BUILTIN_FAST",
             "unused/1 + unused/2 + _CALL_BUILTIN_FAST + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_BUILTIN_FAST_WITH_KEYWORDS",
             "unused/1 + unused/2 + _CALL_BUILTIN_FAST_WITH_KEYWORDS + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_LEN",
             "unused/1 + unused/2 + _GUARD_NOS_NULL + _GUARD_CALLABLE_LEN + _CALL_LEN"
         ),
         Macro(
             "CALL_LIST_APPEND",
             "unused/1 + unused/2 + _CALL_LIST_APPEND + _SKIP_POP_TOP"
         ),
         Macro(
             "CALL_METHOD_DESCRIPTOR_O",
             "unused/1 + unused/2 + _CALL_METHOD_DESCRIPTOR_O + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS",
             "unused/1 + unused/2 + _CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_METHOD_DESCRIPTOR_NOARGS",
             "unused/1 + unused/2 + _CALL_METHOD_DESCRIPTOR_NOARGS + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_METHOD_DESCRIPTOR_FAST",
             "unused/1 + unused/2 + _CALL_METHOD_DESCRIPTOR_FAST + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL",
             "_SPECIALIZE_CALL + unused/2 + _MAYBE_EXPAND_METHOD + _DO_CALL + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_PY_EXACT_ARGS",
             "unused/1 + _CHECK_PEP_523 + _CHECK_FUNCTION_VERSION + _CHECK_FUNCTION_EXACT_ARGS + _CHECK_STACK_SPACE + _CHECK_RECURSION_REMAINING + _INIT_CALL_PY_EXACT_ARGS + _SAVE_RETURN_OFFSET + _PUSH_FRAME"
         ),
         Macro(
             "CALL_BOUND_METHOD_EXACT_ARGS",
             "unused/1 + _CHECK_PEP_523 + _CHECK_METHOD_VERSION + _CHECK_METHOD_EXACT_ARGS + _CHECK_METHOD_STACK_SPACE + _CHECK_RECURSION_REMAINING + _INIT_CALL_BOUND_METHOD_EXACT_ARGS + _INIT_CALL_PY_EXACT_ARGS + _SAVE_RETURN_OFFSET + _PUSH_FRAME"
         ),
         Macro(
             "CALL_PY_GENERAL",
             "unused/1 + _CHECK_PEP_523 + _CHECK_FUNCTION_VERSION + _CHECK_RECURSION_REMAINING + _PY_FRAME_GENERAL + _SAVE_RETURN_OFFSET + _PUSH_FRAME"
         ),
         Macro(
             "CALL_BOUND_METHOD_GENERAL",
             "unused/1 + _CHECK_PEP_523 + _CHECK_METHOD_VERSION + _CHECK_RECURSION_REMAINING + _EXPAND_METHOD + _PY_FRAME_GENERAL + _SAVE_RETURN_OFFSET + _PUSH_FRAME"
         ),
         Macro(
             "CALL_NON_PY_GENERAL",
             "unused/1 + unused/2 + _CHECK_IS_NOT_PY_CALLABLE + _CALL_NON_PY_GENERAL + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_ALLOC_AND_ENTER_INIT",
             "unused/1 + _CHECK_PEP_523 + _CHECK_AND_ALLOCATE_OBJECT + _CREATE_INIT_FRAME + _PUSH_FRAME"
         ),
         Macro(
             "CALL_KW",
             "_SPECIALIZE_CALL_KW + unused/2 + _MAYBE_EXPAND_METHOD_KW + _DO_CALL_KW"
         ),
         Macro(
             "CALL_KW_PY",
             "unused/1 + _CHECK_PEP_523 + _CHECK_FUNCTION_VERSION_KW + _CHECK_RECURSION_REMAINING + _PY_FRAME_KW + _SAVE_RETURN_OFFSET + _PUSH_FRAME"
         ),
         Macro(
             "CALL_KW_BOUND_METHOD",
             "unused/1 + _CHECK_PEP_523 + _CHECK_METHOD_VERSION_KW + _EXPAND_METHOD_KW + _PY_FRAME_KW + _SAVE_RETURN_OFFSET + _PUSH_FRAME"
         ),
         Macro(
             "CALL_KW_NON_PY",
             "unused/1 + unused/2 + _CHECK_IS_NOT_PY_CALLABLE_KW + _CALL_KW_NON_PY + _CHECK_PERIODIC"
         ),
         Macro(
             "CALL_FUNCTION_EX",
             "_MAKE_CALLARGS_A_TUPLE + _DO_CALL_FUNCTION_EX + _CHECK_PERIODIC"
         ),
         Macro("RETURN_GENERATOR", "_MAKE_GENERATOR + _RETURN_GENERATOR"),
         Macro(
             "RESUME",
             "_LOAD_BYTECODE + _MAYBE_INSTRUMENT + _QUICKEN_RESUME + _CHECK_PERIODIC_IF_NOT_YIELD_FROM"
         ),
         Macro(
             "JUMP_BACKWARD",
             "unused/1 + _SPECIALIZE_JUMP_BACKWARD + _CHECK_PERIODIC + JUMP_BACKWARD_NO_INTERRUPT"
         ),
         Macro(
             "JUMP_BACKWARD_NO_JIT",
             "unused/1 + _CHECK_PERIODIC + JUMP_BACKWARD_NO_INTERRUPT"
         ),
         Macro(
             "JUMP_BACKWARD_JIT",
             "unused/1 + _CHECK_PERIODIC + JUMP_BACKWARD_NO_INTERRUPT + _JIT"
         ),
         Macro("BINARY_OP", "_SPECIALIZE_BINARY_OP + unused/4 + _BINARY_OP"),
         Macro(
             "BINARY_OP_MULTIPLY_FLOAT",
             "_GUARD_TOS_FLOAT + _GUARD_NOS_FLOAT + unused/5 + _BINARY_OP_MULTIPLY_FLOAT"
         ),
         Macro(
             "BINARY_OP_ADD_FLOAT",
             "_GUARD_TOS_FLOAT + _GUARD_NOS_FLOAT + unused/5 + _BINARY_OP_ADD_FLOAT"
         ),
         Macro(
             "BINARY_OP_SUBTRACT_FLOAT",
             "_GUARD_TOS_FLOAT + _GUARD_NOS_FLOAT + unused/5 + _BINARY_OP_SUBTRACT_FLOAT"
         ),
         Macro(
             "BINARY_OP_ADD_UNICODE",
             "_GUARD_TOS_UNICODE + _GUARD_NOS_UNICODE + unused/5 + _BINARY_OP_ADD_UNICODE"
         ),
         Macro(
             "BINARY_OP_INPLACE_ADD_UNICODE",
             "_GUARD_TOS_UNICODE + _GUARD_NOS_UNICODE + unused/5 + _BINARY_OP_INPLACE_ADD_UNICODE + _SKIP_STORE_FAST"
         ),
         Macro(
             "BINARY_OP_EXTEND",
             "unused/1 + _GUARD_BINARY_OP_EXTEND + _BINARY_OP_EXTEND"
         ),
         Macro(
             "BINARY_OP_SUBSCR_LIST_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_LIST + unused/5 + _BINARY_OP_SUBSCR_LIST_INT"
         ),
         Macro(
             "BINARY_OP_SUBSCR_LIST_SLICE",
             "_GUARD_TOS_SLICE + _GUARD_NOS_LIST + unused/5 + _BINARY_OP_SUBSCR_LIST_SLICE"
         ),
         Macro(
             "BINARY_OP_SUBSCR_STR_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_UNICODE + unused/5 + _BINARY_OP_SUBSCR_STR_INT"
         ),
         Macro(
             "BINARY_OP_SUBSCR_TUPLE_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_TUPLE + unused/5 + _BINARY_OP_SUBSCR_TUPLE_INT"
         ),
         Macro(
             "BINARY_OP_SUBSCR_DICT",
             "_GUARD_NOS_DICT + unused/5 + _BINARY_OP_SUBSCR_DICT"
         ),
         Macro(
             "BINARY_OP_SUBSCR_GETITEM",
             "unused/5 + _CHECK_PEP_523 + _BINARY_OP_SUBSCR_CHECK_FUNC + _BINARY_OP_SUBSCR_INIT_CALL + _PUSH_FRAME"
         ),
         Macro("BINARY_SLICE", "_SPECIALIZE_BINARY_SLICE + _BINARY_SLICE"),
         Macro("STORE_SLICE", "_SPECIALIZE_STORE_SLICE + _STORE_SLICE"),
         Macro("STORE_SUBSCR", "_SPECIALIZE_STORE_SUBSCR + _STORE_SUBSCR"),
         Macro(
             "STORE_SUBSCR_LIST_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_LIST + unused/1 + _STORE_SUBSCR_LIST_INT"
         ),
         Macro("STORE_SUBSCR_DICT", "_GUARD_NOS_DICT + unused/1 + _STORE_SUBSCR_DICT"),
         Macro("COMPARE_OP", "_SPECIALIZE_COMPARE_OP + _COMPARE_OP"),
         Macro(
             "COMPARE_OP_FLOAT",
             "_GUARD_TOS_FLOAT + _GUARD_NOS_FLOAT + unused/1 + _COMPARE_OP_FLOAT"
         ),
         Macro(
             "COMPARE_OP_INT",
             "_GUARD_TOS_INT + _GUARD_NOS_INT + unused/1 + _COMPARE_OP_INT"
         ),
         Macro(
             "COMPARE_OP_STR",
             "_GUARD_TOS_UNICODE + _GUARD_NOS_UNICODE + unused/1 + _COMPARE_OP_STR"
         ),
         Macro("CONTAINS_OP", "_SPECIALIZE_CONTAINS_OP + _CONTAINS_OP"),
         Macro("CONTAINS_OP_SET", "_GUARD_TOS_ANY_SET + unused/1 + _CONTAINS_OP_SET"),
         Macro("CONTAINS_OP_DICT", "_GUARD_TOS_DICT + unused/1 + _CONTAINS_OP_DICT"),
         Macro("TO_BOOL", "_SPECIALIZE_TO_BOOL + unused/2 + _TO_BOOL"),
         Macro("TO_BOOL_LIST", "_GUARD_TOS_LIST + unused/1 + unused/2 + _TO_BOOL_LIST"),
         Macro(
             "TO_BOOL_STR", "_GUARD_TOS_UNICODE + unused/1 + unused/2 + _TO_BOOL_STR"
         ),
         Macro(
             "TO_BOOL_ALWAYS_TRUE",
             "unused/1 + _GUARD_TYPE_VERSION + _REPLACE_WITH_TRUE"
         ),
         Macro("POP_ITER", "POP_TOP"),
         Macro("END_ASYNC_FOR", "_END_ASYNC_FOR"),
         Macro("FOR_ITER", "_SPECIALIZE_FOR_ITER + _FOR_ITER"),
         Macro(
             "FOR_ITER_LIST",
             "unused/1 + _ITER_CHECK_LIST + _ITER_JUMP_LIST + _ITER_NEXT_LIST"
         ),
         Macro(
             "FOR_ITER_TUPLE",
             "unused/1 + _ITER_CHECK_TUPLE + _ITER_JUMP_TUPLE + _ITER_NEXT_TUPLE"
         ),
         Macro(
             "FOR_ITER_RANGE",
             "unused/1 + _ITER_CHECK_RANGE + _ITER_JUMP_RANGE + _ITER_NEXT_RANGE"
         ),
         Macro(
             "FOR_ITER_GEN",
             "unused/1 + _CHECK_PEP_523 + _FOR_ITER_GEN_FRAME + _PUSH_FRAME"
         ),
         Macro("SEND", "_SPECIALIZE_SEND + _SEND"),
         Macro("SEND_GEN", "unused/1 + _CHECK_PEP_523 + _SEND_GEN_FRAME + _PUSH_FRAME"),
         Macro(
             "INSTRUMENTED_RESUME",
             "_LOAD_BYTECODE + _MAYBE_INSTRUMENT + _CHECK_PERIODIC_IF_NOT_YIELD_FROM + _MONITOR_RESUME"
         ),
         Macro("INSTRUMENTED_RETURN_VALUE", "_RETURN_VALUE_EVENT + RETURN_VALUE"),
         Macro("INSTRUMENTED_YIELD_VALUE", "_YIELD_VALUE_EVENT + YIELD_VALUE"),
         Macro(
             "INSTRUMENTED_CALL",
             "unused/3 + _MAYBE_EXPAND_METHOD + _MONITOR_CALL + _DO_CALL_INSTRUMENTED + _CHECK_PERIODIC"
         ),
         Macro(
             "INSTRUMENTED_CALL_KW",
             "unused/3 + _MAYBE_EXPAND_METHOD_KW + _MONITOR_CALL_KW + _DO_CALL_KW_INSTRUMENTED"
         ),
         Macro(
             "INSTRUMENTED_CALL_FUNCTION_EX",
             "_MAKE_CALLARGS_A_TUPLE + _DO_CALL_FUNCTION_EX_INSTRUMENTED + _CHECK_PERIODIC"
         ),
         Macro("LOAD_ATTR", "_SPECIALIZE_LOAD_ATTR + unused/8 + _LOAD_ATTR"),
         Macro(
             "LOAD_ATTR_INSTANCE_VALUE",
             "unused/1 + _GUARD_TYPE_VERSION + _CHECK_MANAGED_OBJECT_HAS_VALUES + _LOAD_ATTR_INSTANCE_VALUE + unused/5 + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_ATTR_MODULE",
             "unused/1 + _LOAD_ATTR_MODULE + unused/5 + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_ATTR_WITH_HINT",
             "unused/1 + _GUARD_TYPE_VERSION + _LOAD_ATTR_WITH_HINT + unused/5 + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_ATTR_SLOT",
             "unused/1 + _GUARD_TYPE_VERSION + _LOAD_ATTR_SLOT + unused/5 + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_ATTR_CLASS",
             "unused/1 + _CHECK_ATTR_CLASS + unused/2 + _LOAD_ATTR_CLASS + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_ATTR_CLASS_WITH_METACLASS_CHECK",
             "unused/1 + _CHECK_ATTR_CLASS + _GUARD_TYPE_VERSION + _LOAD_ATTR_CLASS + _PUSH_NULL_CONDITIONAL"
         ),
         Macro(
             "LOAD_ATTR_PROPERTY",
             "unused/1 + _CHECK_PEP_523 + _GUARD_TYPE_VERSION + unused/2 + _LOAD_ATTR_PROPERTY_FRAME + _SAVE_RETURN_OFFSET + _PUSH_FRAME"
         ),
         Macro(
             "LOAD_ATTR_METHOD_WITH_VALUES",
             "unused/1 + _GUARD_TYPE_VERSION + _GUARD_DORV_VALUES_INST_ATTR_FROM_DICT + _GUARD_KEYS_VERSION + _LOAD_ATTR_METHOD_WITH_VALUES"
         ),
         Macro(
             "LOAD_ATTR_METHOD_NO_DICT",
             "unused/1 + _GUARD_TYPE_VERSION + unused/2 + _LOAD_ATTR_METHOD_NO_DICT"
         ),
         Macro(
             "LOAD_ATTR_METHOD_LAZY_DICT",
             "unused/1 + _GUARD_TYPE_VERSION + _CHECK_ATTR_METHOD_LAZY_DICT + unused/1 + _LOAD_ATTR_METHOD_LAZY_DICT"
         ),
         Macro(
             "LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES",
             "unused/1 + _GUARD_TYPE_VERSION + _GUARD_DORV_VALUES_INST_ATTR_FROM_DICT + _GUARD_KEYS_VERSION + _LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES"
         ),
         Macro(
             "LOAD_ATTR_NONDESCRIPTOR_NO_DICT",
             "unused/1 + _GUARD_TYPE_VERSION + unused/2 + _LOAD_ATTR_NONDESCRIPTOR_NO_DICT"
         ),
         Macro(
             "LOAD_SUPER_ATTR",
             "_SPECIALIZE_LOAD_SUPER_ATTR + _LOAD_SUPER_ATTR + _PUSH_NULL_CONDITIONAL"
         ),
         Macro("LOAD_SPECIAL", "_INSERT_NULL + _LOAD_SPECIAL"),
         Macro("STORE_ATTR", "_SPECIALIZE_STORE_ATTR + unused/3 + _STORE_ATTR"),
         Macro(
             "STORE_ATTR_INSTANCE_VALUE",
             "unused/1 + _GUARD_TYPE_VERSION_AND_LOCK + _GUARD_DORV_NO_DICT + _STORE_ATTR_INSTANCE_VALUE"
         ),
         Macro(
             "STORE_ATTR_WITH_HINT",
             "unused/1 + _GUARD_TYPE_VERSION + _STORE_ATTR_WITH_HINT"
         ),
         Macro("STORE_ATTR_SLOT", "unused/1 + _GUARD_TYPE_VERSION + _STORE_ATTR_SLOT"),
         Macro(
             "INSTRUMENTED_LOAD_SUPER_ATTR",
             "unused/1 + _LOAD_SUPER_ATTR_INSTRUMENTED + _PUSH_NULL_CONDITIONAL"
         )
     ],
     FAMILIES: list[Family] = [
         Family(
             "BINARY_OP",
             [
                 "BINARY_OP_MULTIPLY_INT",
                 "BINARY_OP_ADD_INT",
                 "BINARY_OP_SUBTRACT_INT",
                 "BINARY_OP_MULTIPLY_FLOAT",
                 "BINARY_OP_ADD_FLOAT",
                 "BINARY_OP_SUBTRACT_FLOAT",
                 "BINARY_OP_ADD_UNICODE",
                 "BINARY_OP_SUBSCR_LIST_INT",
                 "BINARY_OP_SUBSCR_LIST_SLICE",
                 "BINARY_OP_SUBSCR_TUPLE_INT",
                 "BINARY_OP_SUBSCR_STR_INT",
                 "BINARY_OP_SUBSCR_DICT",
                 "BINARY_OP_SUBSCR_GETITEM",
                 "BINARY_OP_INPLACE_ADD_UNICODE",
                 "BINARY_OP_EXTEND"
             ]
         ),
         Family("LOAD_CONST", ["LOAD_CONST_MORTAL", "LOAD_CONST_IMMORTAL"]),
         Family("LOAD_GLOBAL", ["LOAD_GLOBAL_MODULE", "LOAD_GLOBAL_BUILTIN"]),
         Family(
             "UNPACK_SEQUENCE",
             [
                 "UNPACK_SEQUENCE_TWO_TUPLE",
                 "UNPACK_SEQUENCE_TUPLE",
                 "UNPACK_SEQUENCE_LIST"
             ]
         ),
         Family(
             "CALL",
             [
                 "CALL_TYPE_1",
                 "CALL_STR_1",
                 "CALL_TUPLE_1",
                 "CALL_BUILTIN_CLASS",
                 "CALL_BUILTIN_O",
                 "CALL_BUILTIN_FAST",
                 "CALL_BUILTIN_FAST_WITH_KEYWORDS",
                 "CALL_LEN",
                 "CALL_ISINSTANCE",
                 "CALL_LIST_APPEND",
                 "CALL_METHOD_DESCRIPTOR_O",
                 "CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS",
                 "CALL_METHOD_DESCRIPTOR_NOARGS",
                 "CALL_METHOD_DESCRIPTOR_FAST",
                 "CALL_BOUND_METHOD_EXACT_ARGS",
                 "CALL_PY_EXACT_ARGS",
                 "CALL_ALLOC_AND_ENTER_INIT",
                 "CALL_PY_GENERAL",
                 "CALL_BOUND_METHOD_GENERAL",
                 "CALL_NON_PY_GENERAL"
             ]
         ),
         Family("CALL_KW", ["CALL_KW_BOUND_METHOD", "CALL_KW_PY", "CALL_KW_NON_PY"]),
         Family("RESUME", ["RESUME_CHECK"]),
         Family("JUMP_BACKWARD", ["JUMP_BACKWARD_NO_JIT", "JUMP_BACKWARD_JIT"]),
         Family("COMPARE_OP", ["COMPARE_OP_FLOAT", "COMPARE_OP_INT", "COMPARE_OP_STR"]),
         Family("CONTAINS_OP", ["CONTAINS_OP_SET", "CONTAINS_OP_DICT"]),
         Family("STORE_SUBSCR", ["STORE_SUBSCR_DICT", "STORE_SUBSCR_LIST_INT"]),
         Family(
             "TO_BOOL",
             [
                 "TO_BOOL_ALWAYS_TRUE",
                 "TO_BOOL_BOOL",
                 "TO_BOOL_INT",
                 "TO_BOOL_LIST",
                 "TO_BOOL_NONE",
                 "TO_BOOL_STR"
             ]
         ),
         Family(
             "FOR_ITER",
             ["FOR_ITER_LIST", "FOR_ITER_TUPLE", "FOR_ITER_RANGE", "FOR_ITER_GEN"]
         ),
         Family("SEND", ["SEND_GEN"]),
         Family(
             "LOAD_ATTR",
             [
                 "LOAD_ATTR_INSTANCE_VALUE",
                 "LOAD_ATTR_MODULE",
                 "LOAD_ATTR_WITH_HINT",
                 "LOAD_ATTR_SLOT",
                 "LOAD_ATTR_CLASS",
                 "LOAD_ATTR_CLASS_WITH_METACLASS_CHECK",
                 "LOAD_ATTR_PROPERTY",
                 "LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN",
                 "LOAD_ATTR_METHOD_WITH_VALUES",
                 "LOAD_ATTR_METHOD_NO_DICT",
                 "LOAD_ATTR_METHOD_LAZY_DICT",
                 "LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES",
                 "LOAD_ATTR_NONDESCRIPTOR_NO_DICT"
             ]
         ),
         Family("LOAD_SUPER_ATTR", ["LOAD_SUPER_ATTR_ATTR", "LOAD_SUPER_ATTR_METHOD"]),
         Family(
             "STORE_ATTR",
             ["STORE_ATTR_INSTANCE_VALUE", "STORE_ATTR_SLOT", "STORE_ATTR_WITH_HINT"]
         )
     ];
