import from c {
    @__preserve_none
    def _TAIL_CALL_BINARY_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_ADD_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_ADD_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_ADD_UNICODE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_EXTEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_INPLACE_ADD_UNICODE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_MULTIPLY_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_MULTIPLY_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_GETITEM(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_LIST_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_LIST_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_STR_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_TUPLE_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBTRACT_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBTRACT_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BINARY_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_INTERPOLATION(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_MAP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_SET(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_STRING(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_TEMPLATE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_BUILD_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CACHE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_ALLOC_AND_ENTER_INIT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_BOUND_METHOD_EXACT_ARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_BOUND_METHOD_GENERAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_CLASS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_FAST_WITH_KEYWORDS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_O(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_FUNCTION_EX(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_INTRINSIC_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_INTRINSIC_2(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_ISINSTANCE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_KW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_KW_BOUND_METHOD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_KW_NON_PY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_KW_PY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_LEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_LIST_APPEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_NOARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_O(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_NON_PY_GENERAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_PY_EXACT_ARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_PY_GENERAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_STR_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_TUPLE_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CALL_TYPE_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CHECK_EG_MATCH(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CHECK_EXC_MATCH(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CLEANUP_THROW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_COMPARE_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_COMPARE_OP_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_COMPARE_OP_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_COMPARE_OP_STR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CONTAINS_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CONTAINS_OP_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CONTAINS_OP_SET(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_CONVERT_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_COPY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_COPY_FREE_VARS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DELETE_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DELETE_DEREF(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DELETE_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DELETE_GLOBAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DELETE_NAME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DELETE_SUBSCR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DICT_MERGE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_DICT_UPDATE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_END_ASYNC_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_END_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_END_SEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_ENTER_EXECUTOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_EXIT_INIT_CHECK(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_EXTENDED_ARG(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_FORMAT_SIMPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_FORMAT_WITH_SPEC(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_FOR_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_FOR_ITER_GEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_FOR_ITER_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_FOR_ITER_RANGE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_FOR_ITER_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_GET_AITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_GET_ANEXT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_GET_AWAITABLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_GET_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_GET_LEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_GET_YIELD_FROM_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_IMPORT_FROM(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_IMPORT_NAME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_CALL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_CALL_FUNCTION_EX(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_CALL_KW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_END_ASYNC_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_END_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_END_SEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_FOR_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_INSTRUCTION(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_JUMP_BACKWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_JUMP_FORWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_LINE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_LOAD_SUPER_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_NOT_TAKEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_FALSE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_NOT_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_TRUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_RESUME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_RETURN_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_YIELD_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INTERPRETER_EXIT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_IS_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD_JIT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD_NO_INTERRUPT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD_NO_JIT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_JUMP_FORWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LIST_APPEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LIST_EXTEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_CLASS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_INSTANCE_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_METHOD_LAZY_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_METHOD_NO_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_METHOD_WITH_VALUES(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_MODULE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_NONDESCRIPTOR_NO_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_PROPERTY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_SLOT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_WITH_HINT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_BUILD_CLASS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_COMMON_CONSTANT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_CONST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_CONST_IMMORTAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_CONST_MORTAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_DEREF(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_AND_CLEAR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_BORROW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_BORROW_LOAD_FAST_BORROW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_CHECK(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_LOAD_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FROM_DICT_OR_DEREF(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_FROM_DICT_OR_GLOBALS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_GLOBAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_GLOBAL_BUILTIN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_GLOBAL_MODULE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_LOCALS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_NAME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_SMALL_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_SPECIAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_SUPER_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_SUPER_ATTR_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_LOAD_SUPER_ATTR_METHOD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_MAKE_CELL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_MAKE_FUNCTION(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_MAP_ADD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_MATCH_CLASS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_MATCH_KEYS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_MATCH_MAPPING(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_MATCH_SEQUENCE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_NOP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_NOT_TAKEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_POP_EXCEPT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_POP_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_FALSE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_NOT_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_TRUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_POP_TOP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_PUSH_EXC_INFO(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_PUSH_NULL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_RAISE_VARARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_RERAISE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_RESERVED(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_RESUME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_RESUME_CHECK(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_RETURN_GENERATOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_RETURN_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_SEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_SEND_GEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_SETUP_ANNOTATIONS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_SET_ADD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_SET_FUNCTION_ATTRIBUTE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_SET_UPDATE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_ATTR_INSTANCE_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_ATTR_SLOT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_ATTR_WITH_HINT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_DEREF(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_FAST_LOAD_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_FAST_STORE_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_GLOBAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_NAME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_SUBSCR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_SUBSCR_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_STORE_SUBSCR_LIST_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_SWAP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_TO_BOOL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_TO_BOOL_ALWAYS_TRUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_TO_BOOL_BOOL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_TO_BOOL_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_TO_BOOL_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_TO_BOOL_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_TO_BOOL_STR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNARY_INVERT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNARY_NEGATIVE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNARY_NOT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNKNOWN_OPCODE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNPACK_EX(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE_TWO_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_WITH_EXCEPT_START(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_YIELD_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  glob INSTRUCTION_TABLE: list[HandlerSlot] = [
             HandlerSlot(handler=_TAIL_CALL_CACHE),
             HandlerSlot(handler=_TAIL_CALL_BINARY_SLICE),
             HandlerSlot(handler=_TAIL_CALL_BUILD_TEMPLATE),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_INPLACE_ADD_UNICODE),
             HandlerSlot(handler=_TAIL_CALL_CALL_FUNCTION_EX),
             HandlerSlot(handler=_TAIL_CALL_CHECK_EG_MATCH),
             HandlerSlot(handler=_TAIL_CALL_CHECK_EXC_MATCH),
             HandlerSlot(handler=_TAIL_CALL_CLEANUP_THROW),
             HandlerSlot(handler=_TAIL_CALL_DELETE_SUBSCR),
             HandlerSlot(handler=_TAIL_CALL_END_FOR),
             HandlerSlot(handler=_TAIL_CALL_END_SEND),
             HandlerSlot(handler=_TAIL_CALL_EXIT_INIT_CHECK),
             HandlerSlot(handler=_TAIL_CALL_FORMAT_SIMPLE),
             HandlerSlot(handler=_TAIL_CALL_FORMAT_WITH_SPEC),
             HandlerSlot(handler=_TAIL_CALL_GET_AITER),
             HandlerSlot(handler=_TAIL_CALL_GET_ANEXT),
             HandlerSlot(handler=_TAIL_CALL_GET_ITER),
             HandlerSlot(handler=_TAIL_CALL_RESERVED),
             HandlerSlot(handler=_TAIL_CALL_GET_LEN),
             HandlerSlot(handler=_TAIL_CALL_GET_YIELD_FROM_ITER),
             HandlerSlot(handler=_TAIL_CALL_INTERPRETER_EXIT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_BUILD_CLASS),
             HandlerSlot(handler=_TAIL_CALL_LOAD_LOCALS),
             HandlerSlot(handler=_TAIL_CALL_MAKE_FUNCTION),
             HandlerSlot(handler=_TAIL_CALL_MATCH_KEYS),
             HandlerSlot(handler=_TAIL_CALL_MATCH_MAPPING),
             HandlerSlot(handler=_TAIL_CALL_MATCH_SEQUENCE),
             HandlerSlot(handler=_TAIL_CALL_NOP),
             HandlerSlot(handler=_TAIL_CALL_NOT_TAKEN),
             HandlerSlot(handler=_TAIL_CALL_POP_EXCEPT),
             HandlerSlot(handler=_TAIL_CALL_POP_ITER),
             HandlerSlot(handler=_TAIL_CALL_POP_TOP),
             HandlerSlot(handler=_TAIL_CALL_PUSH_EXC_INFO),
             HandlerSlot(handler=_TAIL_CALL_PUSH_NULL),
             HandlerSlot(handler=_TAIL_CALL_RETURN_GENERATOR),
             HandlerSlot(handler=_TAIL_CALL_RETURN_VALUE),
             HandlerSlot(handler=_TAIL_CALL_SETUP_ANNOTATIONS),
             HandlerSlot(handler=_TAIL_CALL_STORE_SLICE),
             HandlerSlot(handler=_TAIL_CALL_STORE_SUBSCR),
             HandlerSlot(handler=_TAIL_CALL_TO_BOOL),
             HandlerSlot(handler=_TAIL_CALL_UNARY_INVERT),
             HandlerSlot(handler=_TAIL_CALL_UNARY_NEGATIVE),
             HandlerSlot(handler=_TAIL_CALL_UNARY_NOT),
             HandlerSlot(handler=_TAIL_CALL_WITH_EXCEPT_START),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP),
             HandlerSlot(handler=_TAIL_CALL_BUILD_INTERPOLATION),
             HandlerSlot(handler=_TAIL_CALL_BUILD_LIST),
             HandlerSlot(handler=_TAIL_CALL_BUILD_MAP),
             HandlerSlot(handler=_TAIL_CALL_BUILD_SET),
             HandlerSlot(handler=_TAIL_CALL_BUILD_SLICE),
             HandlerSlot(handler=_TAIL_CALL_BUILD_STRING),
             HandlerSlot(handler=_TAIL_CALL_BUILD_TUPLE),
             HandlerSlot(handler=_TAIL_CALL_CALL),
             HandlerSlot(handler=_TAIL_CALL_CALL_INTRINSIC_1),
             HandlerSlot(handler=_TAIL_CALL_CALL_INTRINSIC_2),
             HandlerSlot(handler=_TAIL_CALL_CALL_KW),
             HandlerSlot(handler=_TAIL_CALL_COMPARE_OP),
             HandlerSlot(handler=_TAIL_CALL_CONTAINS_OP),
             HandlerSlot(handler=_TAIL_CALL_CONVERT_VALUE),
             HandlerSlot(handler=_TAIL_CALL_COPY),
             HandlerSlot(handler=_TAIL_CALL_COPY_FREE_VARS),
             HandlerSlot(handler=_TAIL_CALL_DELETE_ATTR),
             HandlerSlot(handler=_TAIL_CALL_DELETE_DEREF),
             HandlerSlot(handler=_TAIL_CALL_DELETE_FAST),
             HandlerSlot(handler=_TAIL_CALL_DELETE_GLOBAL),
             HandlerSlot(handler=_TAIL_CALL_DELETE_NAME),
             HandlerSlot(handler=_TAIL_CALL_DICT_MERGE),
             HandlerSlot(handler=_TAIL_CALL_DICT_UPDATE),
             HandlerSlot(handler=_TAIL_CALL_END_ASYNC_FOR),
             HandlerSlot(handler=_TAIL_CALL_EXTENDED_ARG),
             HandlerSlot(handler=_TAIL_CALL_FOR_ITER),
             HandlerSlot(handler=_TAIL_CALL_GET_AWAITABLE),
             HandlerSlot(handler=_TAIL_CALL_IMPORT_FROM),
             HandlerSlot(handler=_TAIL_CALL_IMPORT_NAME),
             HandlerSlot(handler=_TAIL_CALL_IS_OP),
             HandlerSlot(handler=_TAIL_CALL_JUMP_BACKWARD),
             HandlerSlot(handler=_TAIL_CALL_JUMP_BACKWARD_NO_INTERRUPT),
             HandlerSlot(handler=_TAIL_CALL_JUMP_FORWARD),
             HandlerSlot(handler=_TAIL_CALL_LIST_APPEND),
             HandlerSlot(handler=_TAIL_CALL_LIST_EXTEND),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR),
             HandlerSlot(handler=_TAIL_CALL_LOAD_COMMON_CONSTANT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_CONST),
             HandlerSlot(handler=_TAIL_CALL_LOAD_DEREF),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FAST),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FAST_AND_CLEAR),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FAST_BORROW),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FAST_BORROW_LOAD_FAST_BORROW),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FAST_CHECK),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FAST_LOAD_FAST),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FROM_DICT_OR_DEREF),
             HandlerSlot(handler=_TAIL_CALL_LOAD_FROM_DICT_OR_GLOBALS),
             HandlerSlot(handler=_TAIL_CALL_LOAD_GLOBAL),
             HandlerSlot(handler=_TAIL_CALL_LOAD_NAME),
             HandlerSlot(handler=_TAIL_CALL_LOAD_SMALL_INT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_SPECIAL),
             HandlerSlot(handler=_TAIL_CALL_LOAD_SUPER_ATTR),
             HandlerSlot(handler=_TAIL_CALL_MAKE_CELL),
             HandlerSlot(handler=_TAIL_CALL_MAP_ADD),
             HandlerSlot(handler=_TAIL_CALL_MATCH_CLASS),
             HandlerSlot(handler=_TAIL_CALL_POP_JUMP_IF_FALSE),
             HandlerSlot(handler=_TAIL_CALL_POP_JUMP_IF_NONE),
             HandlerSlot(handler=_TAIL_CALL_POP_JUMP_IF_NOT_NONE),
             HandlerSlot(handler=_TAIL_CALL_POP_JUMP_IF_TRUE),
             HandlerSlot(handler=_TAIL_CALL_RAISE_VARARGS),
             HandlerSlot(handler=_TAIL_CALL_RERAISE),
             HandlerSlot(handler=_TAIL_CALL_SEND),
             HandlerSlot(handler=_TAIL_CALL_SET_ADD),
             HandlerSlot(handler=_TAIL_CALL_SET_FUNCTION_ATTRIBUTE),
             HandlerSlot(handler=_TAIL_CALL_SET_UPDATE),
             HandlerSlot(handler=_TAIL_CALL_STORE_ATTR),
             HandlerSlot(handler=_TAIL_CALL_STORE_DEREF),
             HandlerSlot(handler=_TAIL_CALL_STORE_FAST),
             HandlerSlot(handler=_TAIL_CALL_STORE_FAST_LOAD_FAST),
             HandlerSlot(handler=_TAIL_CALL_STORE_FAST_STORE_FAST),
             HandlerSlot(handler=_TAIL_CALL_STORE_GLOBAL),
             HandlerSlot(handler=_TAIL_CALL_STORE_NAME),
             HandlerSlot(handler=_TAIL_CALL_SWAP),
             HandlerSlot(handler=_TAIL_CALL_UNPACK_EX),
             HandlerSlot(handler=_TAIL_CALL_UNPACK_SEQUENCE),
             HandlerSlot(handler=_TAIL_CALL_YIELD_VALUE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_RESUME),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_ADD_FLOAT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_ADD_INT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_ADD_UNICODE),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_EXTEND),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_MULTIPLY_FLOAT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_MULTIPLY_INT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBSCR_DICT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBSCR_GETITEM),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBSCR_LIST_INT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBSCR_LIST_SLICE),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBSCR_STR_INT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBSCR_TUPLE_INT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBTRACT_FLOAT),
             HandlerSlot(handler=_TAIL_CALL_BINARY_OP_SUBTRACT_INT),
             HandlerSlot(handler=_TAIL_CALL_CALL_ALLOC_AND_ENTER_INIT),
             HandlerSlot(handler=_TAIL_CALL_CALL_BOUND_METHOD_EXACT_ARGS),
             HandlerSlot(handler=_TAIL_CALL_CALL_BOUND_METHOD_GENERAL),
             HandlerSlot(handler=_TAIL_CALL_CALL_BUILTIN_CLASS),
             HandlerSlot(handler=_TAIL_CALL_CALL_BUILTIN_FAST),
             HandlerSlot(handler=_TAIL_CALL_CALL_BUILTIN_FAST_WITH_KEYWORDS),
             HandlerSlot(handler=_TAIL_CALL_CALL_BUILTIN_O),
             HandlerSlot(handler=_TAIL_CALL_CALL_ISINSTANCE),
             HandlerSlot(handler=_TAIL_CALL_CALL_KW_BOUND_METHOD),
             HandlerSlot(handler=_TAIL_CALL_CALL_KW_NON_PY),
             HandlerSlot(handler=_TAIL_CALL_CALL_KW_PY),
             HandlerSlot(handler=_TAIL_CALL_CALL_LEN),
             HandlerSlot(handler=_TAIL_CALL_CALL_LIST_APPEND),
             HandlerSlot(handler=_TAIL_CALL_CALL_METHOD_DESCRIPTOR_FAST),
             HandlerSlot(handler=_TAIL_CALL_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS),
             HandlerSlot(handler=_TAIL_CALL_CALL_METHOD_DESCRIPTOR_NOARGS),
             HandlerSlot(handler=_TAIL_CALL_CALL_METHOD_DESCRIPTOR_O),
             HandlerSlot(handler=_TAIL_CALL_CALL_NON_PY_GENERAL),
             HandlerSlot(handler=_TAIL_CALL_CALL_PY_EXACT_ARGS),
             HandlerSlot(handler=_TAIL_CALL_CALL_PY_GENERAL),
             HandlerSlot(handler=_TAIL_CALL_CALL_STR_1),
             HandlerSlot(handler=_TAIL_CALL_CALL_TUPLE_1),
             HandlerSlot(handler=_TAIL_CALL_CALL_TYPE_1),
             HandlerSlot(handler=_TAIL_CALL_COMPARE_OP_FLOAT),
             HandlerSlot(handler=_TAIL_CALL_COMPARE_OP_INT),
             HandlerSlot(handler=_TAIL_CALL_COMPARE_OP_STR),
             HandlerSlot(handler=_TAIL_CALL_CONTAINS_OP_DICT),
             HandlerSlot(handler=_TAIL_CALL_CONTAINS_OP_SET),
             HandlerSlot(handler=_TAIL_CALL_FOR_ITER_GEN),
             HandlerSlot(handler=_TAIL_CALL_FOR_ITER_LIST),
             HandlerSlot(handler=_TAIL_CALL_FOR_ITER_RANGE),
             HandlerSlot(handler=_TAIL_CALL_FOR_ITER_TUPLE),
             HandlerSlot(handler=_TAIL_CALL_JUMP_BACKWARD_JIT),
             HandlerSlot(handler=_TAIL_CALL_JUMP_BACKWARD_NO_JIT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_CLASS),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_INSTANCE_VALUE),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_METHOD_LAZY_DICT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_METHOD_NO_DICT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_METHOD_WITH_VALUES),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_MODULE),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_NONDESCRIPTOR_NO_DICT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_PROPERTY),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_SLOT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_ATTR_WITH_HINT),
             HandlerSlot(handler=_TAIL_CALL_LOAD_CONST_IMMORTAL),
             HandlerSlot(handler=_TAIL_CALL_LOAD_CONST_MORTAL),
             HandlerSlot(handler=_TAIL_CALL_LOAD_GLOBAL_BUILTIN),
             HandlerSlot(handler=_TAIL_CALL_LOAD_GLOBAL_MODULE),
             HandlerSlot(handler=_TAIL_CALL_LOAD_SUPER_ATTR_ATTR),
             HandlerSlot(handler=_TAIL_CALL_LOAD_SUPER_ATTR_METHOD),
             HandlerSlot(handler=_TAIL_CALL_RESUME_CHECK),
             HandlerSlot(handler=_TAIL_CALL_SEND_GEN),
             HandlerSlot(handler=_TAIL_CALL_STORE_ATTR_INSTANCE_VALUE),
             HandlerSlot(handler=_TAIL_CALL_STORE_ATTR_SLOT),
             HandlerSlot(handler=_TAIL_CALL_STORE_ATTR_WITH_HINT),
             HandlerSlot(handler=_TAIL_CALL_STORE_SUBSCR_DICT),
             HandlerSlot(handler=_TAIL_CALL_STORE_SUBSCR_LIST_INT),
             HandlerSlot(handler=_TAIL_CALL_TO_BOOL_ALWAYS_TRUE),
             HandlerSlot(handler=_TAIL_CALL_TO_BOOL_BOOL),
             HandlerSlot(handler=_TAIL_CALL_TO_BOOL_INT),
             HandlerSlot(handler=_TAIL_CALL_TO_BOOL_LIST),
             HandlerSlot(handler=_TAIL_CALL_TO_BOOL_NONE),
             HandlerSlot(handler=_TAIL_CALL_TO_BOOL_STR),
             HandlerSlot(handler=_TAIL_CALL_UNPACK_SEQUENCE_LIST),
             HandlerSlot(handler=_TAIL_CALL_UNPACK_SEQUENCE_TUPLE),
             HandlerSlot(handler=_TAIL_CALL_UNPACK_SEQUENCE_TWO_TUPLE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_UNKNOWN_OPCODE),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_END_FOR),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_POP_ITER),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_END_SEND),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_FOR_ITER),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_INSTRUCTION),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_JUMP_FORWARD),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_NOT_TAKEN),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_TRUE),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_FALSE),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_NONE),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_NOT_NONE),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_RESUME),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_RETURN_VALUE),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_YIELD_VALUE),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_END_ASYNC_FOR),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_LOAD_SUPER_ATTR),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_CALL),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_CALL_KW),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_CALL_FUNCTION_EX),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_JUMP_BACKWARD),
             HandlerSlot(handler=_TAIL_CALL_INSTRUMENTED_LINE),
             HandlerSlot(handler=_TAIL_CALL_ENTER_EXECUTOR)
         ];
}
