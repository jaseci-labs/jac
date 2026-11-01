import from c {
    obj opcode_metadata {
        has valid_entry: u8 = 0,
            instr_format: u8 = 0,
            flags: u16 = 0;
    }  obj pseudo_targets {
        has as_sequence: u8 = 0,
            target0: u8 = 0,
            target1: u8 = 0,
            target2: u8 = 0,
            target3: u8 = 0;
    }  obj macro_uop {
        has uop: i16 = 0,
            size: i8 = 0,
            offset: i8 = 0;
    }  obj opcode_macro_expansion {
        has nuops: i32 = 0,
            uop0: macro_uop = macro_uop(),
            uop1: macro_uop = macro_uop(),
            uop2: macro_uop = macro_uop(),
            uop3: macro_uop = macro_uop(),
            uop4: macro_uop = macro_uop(),
            uop5: macro_uop = macro_uop(),
            uop6: macro_uop = macro_uop(),
            uop7: macro_uop = macro_uop(),
            uop8: macro_uop = macro_uop(),
            uop9: macro_uop = macro_uop();
    }  glob _PyOpcode_Caches: list[u8] = (
             b"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
             b"\0\0\1\3\0\0\0\0\5\0\0\0\0\0\0\0\3\0\0\3\1\1\0\0\0\0\0\0\0\0\0\0\0\0\1\0"
             b"\0\0\0\1\0\0\0\0\11\0\0\0\0\0\0\0\0\0\0\0\4\0\0\0\1\0\0\0\1\1\1\1\0\0\1"
             b"\0\0\0\4\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
             b"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
             b"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
             b"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
             b"\0\0\0\0\0"
         ),
         _PyOpcode_Deopt: list[u8] = (
             b"\0\1\2,\4\5\6\7\10\11\12\13\14\15\16\17\20\21\22\23\24\25\26\27\30\31\32"
             b"\33\34\35\36\37 !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVW"
             b"XYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\177\200,,,,,,,,,,,,,,4444444477"
             b"744444444444488899FFFFKKPPPPPPPPPPPPPRR\\\\``\200jnnn&&''''''www\324\325"
             b"\326\327\330\331\332\333\334\335\336\337\340\341\342\343\344\345\346\347"
             b"\350\351\352\353\354\355\356\357\360\361\362\363\364\365\366\367\370\371"
             b"\372\373\374\375\376\377"
         ),
         _PyOpcode_OpName: list[ptr[u8]] = [
             ptr[u8]("CACHE"),
             ptr[u8]("BINARY_SLICE"),
             ptr[u8]("BUILD_TEMPLATE"),
             ptr[u8]("BINARY_OP_INPLACE_ADD_UNICODE"),
             ptr[u8]("CALL_FUNCTION_EX"),
             ptr[u8]("CHECK_EG_MATCH"),
             ptr[u8]("CHECK_EXC_MATCH"),
             ptr[u8]("CLEANUP_THROW"),
             ptr[u8]("DELETE_SUBSCR"),
             ptr[u8]("END_FOR"),
             ptr[u8]("END_SEND"),
             ptr[u8]("EXIT_INIT_CHECK"),
             ptr[u8]("FORMAT_SIMPLE"),
             ptr[u8]("FORMAT_WITH_SPEC"),
             ptr[u8]("GET_AITER"),
             ptr[u8]("GET_ANEXT"),
             ptr[u8]("GET_ITER"),
             ptr[u8]("RESERVED"),
             ptr[u8]("GET_LEN"),
             ptr[u8]("GET_YIELD_FROM_ITER"),
             ptr[u8]("INTERPRETER_EXIT"),
             ptr[u8]("LOAD_BUILD_CLASS"),
             ptr[u8]("LOAD_LOCALS"),
             ptr[u8]("MAKE_FUNCTION"),
             ptr[u8]("MATCH_KEYS"),
             ptr[u8]("MATCH_MAPPING"),
             ptr[u8]("MATCH_SEQUENCE"),
             ptr[u8]("NOP"),
             ptr[u8]("NOT_TAKEN"),
             ptr[u8]("POP_EXCEPT"),
             ptr[u8]("POP_ITER"),
             ptr[u8]("POP_TOP"),
             ptr[u8]("PUSH_EXC_INFO"),
             ptr[u8]("PUSH_NULL"),
             ptr[u8]("RETURN_GENERATOR"),
             ptr[u8]("RETURN_VALUE"),
             ptr[u8]("SETUP_ANNOTATIONS"),
             ptr[u8]("STORE_SLICE"),
             ptr[u8]("STORE_SUBSCR"),
             ptr[u8]("TO_BOOL"),
             ptr[u8]("UNARY_INVERT"),
             ptr[u8]("UNARY_NEGATIVE"),
             ptr[u8]("UNARY_NOT"),
             ptr[u8]("WITH_EXCEPT_START"),
             ptr[u8]("BINARY_OP"),
             ptr[u8]("BUILD_INTERPOLATION"),
             ptr[u8]("BUILD_LIST"),
             ptr[u8]("BUILD_MAP"),
             ptr[u8]("BUILD_SET"),
             ptr[u8]("BUILD_SLICE"),
             ptr[u8]("BUILD_STRING"),
             ptr[u8]("BUILD_TUPLE"),
             ptr[u8]("CALL"),
             ptr[u8]("CALL_INTRINSIC_1"),
             ptr[u8]("CALL_INTRINSIC_2"),
             ptr[u8]("CALL_KW"),
             ptr[u8]("COMPARE_OP"),
             ptr[u8]("CONTAINS_OP"),
             ptr[u8]("CONVERT_VALUE"),
             ptr[u8]("COPY"),
             ptr[u8]("COPY_FREE_VARS"),
             ptr[u8]("DELETE_ATTR"),
             ptr[u8]("DELETE_DEREF"),
             ptr[u8]("DELETE_FAST"),
             ptr[u8]("DELETE_GLOBAL"),
             ptr[u8]("DELETE_NAME"),
             ptr[u8]("DICT_MERGE"),
             ptr[u8]("DICT_UPDATE"),
             ptr[u8]("END_ASYNC_FOR"),
             ptr[u8]("EXTENDED_ARG"),
             ptr[u8]("FOR_ITER"),
             ptr[u8]("GET_AWAITABLE"),
             ptr[u8]("IMPORT_FROM"),
             ptr[u8]("IMPORT_NAME"),
             ptr[u8]("IS_OP"),
             ptr[u8]("JUMP_BACKWARD"),
             ptr[u8]("JUMP_BACKWARD_NO_INTERRUPT"),
             ptr[u8]("JUMP_FORWARD"),
             ptr[u8]("LIST_APPEND"),
             ptr[u8]("LIST_EXTEND"),
             ptr[u8]("LOAD_ATTR"),
             ptr[u8]("LOAD_COMMON_CONSTANT"),
             ptr[u8]("LOAD_CONST"),
             ptr[u8]("LOAD_DEREF"),
             ptr[u8]("LOAD_FAST"),
             ptr[u8]("LOAD_FAST_AND_CLEAR"),
             ptr[u8]("LOAD_FAST_BORROW"),
             ptr[u8]("LOAD_FAST_BORROW_LOAD_FAST_BORROW"),
             ptr[u8]("LOAD_FAST_CHECK"),
             ptr[u8]("LOAD_FAST_LOAD_FAST"),
             ptr[u8]("LOAD_FROM_DICT_OR_DEREF"),
             ptr[u8]("LOAD_FROM_DICT_OR_GLOBALS"),
             ptr[u8]("LOAD_GLOBAL"),
             ptr[u8]("LOAD_NAME"),
             ptr[u8]("LOAD_SMALL_INT"),
             ptr[u8]("LOAD_SPECIAL"),
             ptr[u8]("LOAD_SUPER_ATTR"),
             ptr[u8]("MAKE_CELL"),
             ptr[u8]("MAP_ADD"),
             ptr[u8]("MATCH_CLASS"),
             ptr[u8]("POP_JUMP_IF_FALSE"),
             ptr[u8]("POP_JUMP_IF_NONE"),
             ptr[u8]("POP_JUMP_IF_NOT_NONE"),
             ptr[u8]("POP_JUMP_IF_TRUE"),
             ptr[u8]("RAISE_VARARGS"),
             ptr[u8]("RERAISE"),
             ptr[u8]("SEND"),
             ptr[u8]("SET_ADD"),
             ptr[u8]("SET_FUNCTION_ATTRIBUTE"),
             ptr[u8]("SET_UPDATE"),
             ptr[u8]("STORE_ATTR"),
             ptr[u8]("STORE_DEREF"),
             ptr[u8]("STORE_FAST"),
             ptr[u8]("STORE_FAST_LOAD_FAST"),
             ptr[u8]("STORE_FAST_STORE_FAST"),
             ptr[u8]("STORE_GLOBAL"),
             ptr[u8]("STORE_NAME"),
             ptr[u8]("SWAP"),
             ptr[u8]("UNPACK_EX"),
             ptr[u8]("UNPACK_SEQUENCE"),
             ptr[u8]("YIELD_VALUE"),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8]("RESUME"),
             ptr[u8]("BINARY_OP_ADD_FLOAT"),
             ptr[u8]("BINARY_OP_ADD_INT"),
             ptr[u8]("BINARY_OP_ADD_UNICODE"),
             ptr[u8]("BINARY_OP_EXTEND"),
             ptr[u8]("BINARY_OP_MULTIPLY_FLOAT"),
             ptr[u8]("BINARY_OP_MULTIPLY_INT"),
             ptr[u8]("BINARY_OP_SUBSCR_DICT"),
             ptr[u8]("BINARY_OP_SUBSCR_GETITEM"),
             ptr[u8]("BINARY_OP_SUBSCR_LIST_INT"),
             ptr[u8]("BINARY_OP_SUBSCR_LIST_SLICE"),
             ptr[u8]("BINARY_OP_SUBSCR_STR_INT"),
             ptr[u8]("BINARY_OP_SUBSCR_TUPLE_INT"),
             ptr[u8]("BINARY_OP_SUBTRACT_FLOAT"),
             ptr[u8]("BINARY_OP_SUBTRACT_INT"),
             ptr[u8]("CALL_ALLOC_AND_ENTER_INIT"),
             ptr[u8]("CALL_BOUND_METHOD_EXACT_ARGS"),
             ptr[u8]("CALL_BOUND_METHOD_GENERAL"),
             ptr[u8]("CALL_BUILTIN_CLASS"),
             ptr[u8]("CALL_BUILTIN_FAST"),
             ptr[u8]("CALL_BUILTIN_FAST_WITH_KEYWORDS"),
             ptr[u8]("CALL_BUILTIN_O"),
             ptr[u8]("CALL_ISINSTANCE"),
             ptr[u8]("CALL_KW_BOUND_METHOD"),
             ptr[u8]("CALL_KW_NON_PY"),
             ptr[u8]("CALL_KW_PY"),
             ptr[u8]("CALL_LEN"),
             ptr[u8]("CALL_LIST_APPEND"),
             ptr[u8]("CALL_METHOD_DESCRIPTOR_FAST"),
             ptr[u8]("CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS"),
             ptr[u8]("CALL_METHOD_DESCRIPTOR_NOARGS"),
             ptr[u8]("CALL_METHOD_DESCRIPTOR_O"),
             ptr[u8]("CALL_NON_PY_GENERAL"),
             ptr[u8]("CALL_PY_EXACT_ARGS"),
             ptr[u8]("CALL_PY_GENERAL"),
             ptr[u8]("CALL_STR_1"),
             ptr[u8]("CALL_TUPLE_1"),
             ptr[u8]("CALL_TYPE_1"),
             ptr[u8]("COMPARE_OP_FLOAT"),
             ptr[u8]("COMPARE_OP_INT"),
             ptr[u8]("COMPARE_OP_STR"),
             ptr[u8]("CONTAINS_OP_DICT"),
             ptr[u8]("CONTAINS_OP_SET"),
             ptr[u8]("FOR_ITER_GEN"),
             ptr[u8]("FOR_ITER_LIST"),
             ptr[u8]("FOR_ITER_RANGE"),
             ptr[u8]("FOR_ITER_TUPLE"),
             ptr[u8]("JUMP_BACKWARD_JIT"),
             ptr[u8]("JUMP_BACKWARD_NO_JIT"),
             ptr[u8]("LOAD_ATTR_CLASS"),
             ptr[u8]("LOAD_ATTR_CLASS_WITH_METACLASS_CHECK"),
             ptr[u8]("LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN"),
             ptr[u8]("LOAD_ATTR_INSTANCE_VALUE"),
             ptr[u8]("LOAD_ATTR_METHOD_LAZY_DICT"),
             ptr[u8]("LOAD_ATTR_METHOD_NO_DICT"),
             ptr[u8]("LOAD_ATTR_METHOD_WITH_VALUES"),
             ptr[u8]("LOAD_ATTR_MODULE"),
             ptr[u8]("LOAD_ATTR_NONDESCRIPTOR_NO_DICT"),
             ptr[u8]("LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES"),
             ptr[u8]("LOAD_ATTR_PROPERTY"),
             ptr[u8]("LOAD_ATTR_SLOT"),
             ptr[u8]("LOAD_ATTR_WITH_HINT"),
             ptr[u8]("LOAD_CONST_IMMORTAL"),
             ptr[u8]("LOAD_CONST_MORTAL"),
             ptr[u8]("LOAD_GLOBAL_BUILTIN"),
             ptr[u8]("LOAD_GLOBAL_MODULE"),
             ptr[u8]("LOAD_SUPER_ATTR_ATTR"),
             ptr[u8]("LOAD_SUPER_ATTR_METHOD"),
             ptr[u8]("RESUME_CHECK"),
             ptr[u8]("SEND_GEN"),
             ptr[u8]("STORE_ATTR_INSTANCE_VALUE"),
             ptr[u8]("STORE_ATTR_SLOT"),
             ptr[u8]("STORE_ATTR_WITH_HINT"),
             ptr[u8]("STORE_SUBSCR_DICT"),
             ptr[u8]("STORE_SUBSCR_LIST_INT"),
             ptr[u8]("TO_BOOL_ALWAYS_TRUE"),
             ptr[u8]("TO_BOOL_BOOL"),
             ptr[u8]("TO_BOOL_INT"),
             ptr[u8]("TO_BOOL_LIST"),
             ptr[u8]("TO_BOOL_NONE"),
             ptr[u8]("TO_BOOL_STR"),
             ptr[u8]("UNPACK_SEQUENCE_LIST"),
             ptr[u8]("UNPACK_SEQUENCE_TUPLE"),
             ptr[u8]("UNPACK_SEQUENCE_TWO_TUPLE"),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8](),
             ptr[u8]("INSTRUMENTED_END_FOR"),
             ptr[u8]("INSTRUMENTED_POP_ITER"),
             ptr[u8]("INSTRUMENTED_END_SEND"),
             ptr[u8]("INSTRUMENTED_FOR_ITER"),
             ptr[u8]("INSTRUMENTED_INSTRUCTION"),
             ptr[u8]("INSTRUMENTED_JUMP_FORWARD"),
             ptr[u8]("INSTRUMENTED_NOT_TAKEN"),
             ptr[u8]("INSTRUMENTED_POP_JUMP_IF_TRUE"),
             ptr[u8]("INSTRUMENTED_POP_JUMP_IF_FALSE"),
             ptr[u8]("INSTRUMENTED_POP_JUMP_IF_NONE"),
             ptr[u8]("INSTRUMENTED_POP_JUMP_IF_NOT_NONE"),
             ptr[u8]("INSTRUMENTED_RESUME"),
             ptr[u8]("INSTRUMENTED_RETURN_VALUE"),
             ptr[u8]("INSTRUMENTED_YIELD_VALUE"),
             ptr[u8]("INSTRUMENTED_END_ASYNC_FOR"),
             ptr[u8]("INSTRUMENTED_LOAD_SUPER_ATTR"),
             ptr[u8]("INSTRUMENTED_CALL"),
             ptr[u8]("INSTRUMENTED_CALL_KW"),
             ptr[u8]("INSTRUMENTED_CALL_FUNCTION_EX"),
             ptr[u8]("INSTRUMENTED_JUMP_BACKWARD"),
             ptr[u8]("INSTRUMENTED_LINE"),
             ptr[u8]("ENTER_EXECUTOR"),
             ptr[u8]("ANNOTATIONS_PLACEHOLDER"),
             ptr[u8]("JUMP"),
             ptr[u8]("JUMP_IF_FALSE"),
             ptr[u8]("JUMP_IF_TRUE"),
             ptr[u8]("JUMP_NO_INTERRUPT"),
             ptr[u8]("LOAD_CLOSURE"),
             ptr[u8]("POP_BLOCK"),
             ptr[u8]("SETUP_CLEANUP"),
             ptr[u8]("SETUP_FINALLY"),
             ptr[u8]("SETUP_WITH"),
             ptr[u8]("STORE_FAST_MAYBE_NULL")
         ],
         _PyOpcode_opcode_metadata: list[opcode_metadata] = [
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(0)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1952)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17216)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17152)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17152)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(33280)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(2560)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17152)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17152)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(0)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17152)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(512)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(0)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(0)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(2048)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(2048)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(512)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(2560)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(2560)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(0)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(2048)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(512)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(8), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(2048)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(5), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(257)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(257)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(16641)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(17217)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(2049)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17169)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(801)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17157)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17157)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17161)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(17161)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(841)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(9)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(9)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(257)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(3)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(801)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(2081)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(33)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(2081)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(33)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(801)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(33)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17169)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17157)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(4), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17169)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(9)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(9)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(9)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(9)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(777)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(4), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(529)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(545)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(545)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(545)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(2049)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(769)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(513)),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17217)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1280)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1792)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1280)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(896)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1280)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1792)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1792)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(128)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1664)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1792)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1664)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1152)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1280)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(11), flags=u16(1792)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(17281)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1665)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(18305)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(961)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(961)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(961)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1857)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(17281)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1921)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1857)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1921)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(17280)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(897)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1857)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1857)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1857)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1857)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1857)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(18305)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(961)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(961)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(641)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1025)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1025)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1793)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(897)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(129)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1673)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1289)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1545)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(841)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(841)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1025)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1025)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(133)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1665)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1025)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(641)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1537)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1665)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(6), flags=u16(1669)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(3)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(3)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(4), flags=u16(129)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(4), flags=u16(129)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(901)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(17285)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(128)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(129)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(10), flags=u16(1536)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(10), flags=u16(1664)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(4), flags=u16(1669)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(8), flags=u16(1792)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(8), flags=u16(1664)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(1536)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(1024)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(1536)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(1024)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(1024)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(9), flags=u16(1536)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1665)),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(49920)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(512)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17152)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(17161)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(0)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(513)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(513)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17217)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(768)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(17161)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(773)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(17217)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(3), flags=u16(17153)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(17216)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(2), flags=u16(833)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(7), flags=u16(512)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(1), flags=u16(1)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(2048)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(841)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(777)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(777)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(9)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(2081)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(2048)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(2049)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(2049)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(2049)),
             opcode_metadata(valid_entry=u8(1), instr_format=u8(255), flags=u16(545))
         ],
         _PyOpcode_PseudoTargets: list[pseudo_targets] = [
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(27),
                 target1=u8(0),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(77),
                 target1=u8(75),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(1),
                 target0=u8(59),
                 target1=u8(39),
                 target2=u8(100),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(1),
                 target0=u8(59),
                 target1=u8(39),
                 target2=u8(103),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(77),
                 target1=u8(76),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(84),
                 target1=u8(0),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(27),
                 target1=u8(0),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(27),
                 target1=u8(0),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(27),
                 target1=u8(0),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(27),
                 target1=u8(0),
                 target2=u8(0),
                 target3=u8(0)
             ),
             pseudo_targets(
                 as_sequence=u8(0),
                 target0=u8(112),
                 target1=u8(0),
                 target2=u8(0),
                 target3=u8(0)
             )
         ],
         _PyOpcode_macro_expansion: list[opcode_macro_expansion] = [
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(319), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(2), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(404), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(393), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(307), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(5), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(6), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(8), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(9), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(10), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(11), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(12), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(13), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(14), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(15), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(16), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(18), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(19), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(21), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(22), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(23), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(24), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(25), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(26), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(27), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(27), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(29), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(31), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(31), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(32), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(33), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(34), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(35), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(36), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(505), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(506), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(510), size=i8(0), offset=i8(2))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(40), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(41), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(42), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(43), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(302), size=i8(0), offset=i8(4))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(45), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(46), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(47), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(48), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(49), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(50), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(51), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(53), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(54), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(355), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(359), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(58), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(59), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(60), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(61), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(62), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(63), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(64), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(65), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(66), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(67), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(371), size=i8(9), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(71), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(72), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(73), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(74), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(78), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(79), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(427), size=i8(0), offset=i8(8))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(81), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(83), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(442), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(85), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(451), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(451), size=i8(5), offset=i8(0)),
                 uop1=macro_uop(uop=i16(451), size=i8(6), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(88), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(442), size=i8(5), offset=i8(0)),
                 uop1=macro_uop(uop=i16(442), size=i8(6), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(90), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(460), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(483), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(93), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(463), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(414), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(468), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(97), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(98), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(99), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(477), size=i8(9), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(415), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(478), size=i8(9), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(415), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(477), size=i8(9), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(478), size=i8(9), offset=i8(1))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(107), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(108), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(109), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(492), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(111), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(496), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(496), size=i8(5), offset=i8(0)),
                 uop1=macro_uop(uop=i16(442), size=i8(6), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(496), size=i8(5), offset=i8(0)),
                 uop1=macro_uop(uop=i16(496), size=i8(6), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(115), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(116), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(117), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(118), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(513), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(120), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(399), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(388), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(303), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(389), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(304), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(404), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(393), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(305), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(374), size=i8(4), offset=i8(1)),
                 uop1=macro_uop(uop=i16(306), size=i8(4), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(399), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(388), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(308), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(389), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(309), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(387), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(311), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(5)),
                 uop1=macro_uop(uop=i16(310), size=i8(0), offset=i8(5)),
                 uop2=macro_uop(uop=i16(312), size=i8(0), offset=i8(5)),
                 uop3=macro_uop(uop=i16(482), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(390), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(313), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(402), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(390), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(314), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(393), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(315), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(392), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(316), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(399), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(388), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(317), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(389), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(318), size=i8(0), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(334), size=i8(2), offset=i8(1)),
                 uop2=macro_uop(uop=i16(362), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(482), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=10,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(337), size=i8(0), offset=i8(1)),
                 uop2=macro_uop(uop=i16(407), size=i8(0), offset=i8(1)),
                 uop3=macro_uop(uop=i16(340), size=i8(2), offset=i8(1)),
                 uop4=macro_uop(uop=i16(339), size=i8(0), offset=i8(3)),
                 uop5=macro_uop(uop=i16(352), size=i8(0), offset=i8(3)),
                 uop6=macro_uop(uop=i16(351), size=i8(0), offset=i8(3)),
                 uop7=macro_uop(uop=i16(408), size=i8(0), offset=i8(3)),
                 uop8=macro_uop(uop=i16(488), size=i8(7), offset=i8(3)),
                 uop9=macro_uop(uop=i16(482), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=7,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(346), size=i8(2), offset=i8(1)),
                 uop2=macro_uop(uop=i16(368), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(351), size=i8(0), offset=i8(3)),
                 uop4=macro_uop(uop=i16(484), size=i8(0), offset=i8(3)),
                 uop5=macro_uop(uop=i16(488), size=i8(7), offset=i8(3)),
                 uop6=macro_uop(uop=i16(482), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(320), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(321), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(322), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(323), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(150), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=6,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(347), size=i8(2), offset=i8(1)),
                 uop2=macro_uop(uop=i16(369), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(485), size=i8(0), offset=i8(3)),
                 uop4=macro_uop(uop=i16(488), size=i8(7), offset=i8(3)),
                 uop5=macro_uop(uop=i16(482), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(344), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(324), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=6,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(342), size=i8(2), offset=i8(1)),
                 uop2=macro_uop(uop=i16(351), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(485), size=i8(0), offset=i8(3)),
                 uop4=macro_uop(uop=i16(488), size=i8(7), offset=i8(3)),
                 uop5=macro_uop(uop=i16(482), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(391), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(375), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(325), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(155), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(326), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(327), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(328), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(329), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(343), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(330), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=8,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(340), size=i8(2), offset=i8(1)),
                 uop2=macro_uop(uop=i16(339), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(352), size=i8(0), offset=i8(3)),
                 uop4=macro_uop(uop=i16(351), size=i8(0), offset=i8(3)),
                 uop5=macro_uop(uop=i16(408), size=i8(0), offset=i8(3)),
                 uop6=macro_uop(uop=i16(488), size=i8(7), offset=i8(3)),
                 uop7=macro_uop(uop=i16(482), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=6,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(340), size=i8(2), offset=i8(1)),
                 uop2=macro_uop(uop=i16(351), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(484), size=i8(0), offset=i8(3)),
                 uop4=macro_uop(uop=i16(488), size=i8(7), offset=i8(3)),
                 uop5=macro_uop(uop=i16(482), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(391), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(376), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(331), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(391), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(377), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(332), size=i8(0), offset=i8(3)),
                 uop3=macro_uop(uop=i16(349), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(391), size=i8(0), offset=i8(3)),
                 uop1=macro_uop(uop=i16(378), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(333), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(399), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(388), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(356), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(389), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(357), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(404), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(393), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(358), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(398), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(360), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(397), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(361), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(372), size=i8(0), offset=i8(1)),
                 uop2=macro_uop(uop=i16(482), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(416), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(419), size=i8(9), offset=i8(1)),
                 uop2=macro_uop(uop=i16(422), size=i8(9), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(417), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(420), size=i8(9), offset=i8(1)),
                 uop2=macro_uop(uop=i16(424), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(418), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(421), size=i8(9), offset=i8(1)),
                 uop2=macro_uop(uop=i16(425), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(335), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(428), size=i8(4), offset=i8(5)),
                 uop2=macro_uop(uop=i16(483), size=i8(0), offset=i8(9))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(335), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(405), size=i8(2), offset=i8(3)),
                 uop2=macro_uop(uop=i16(428), size=i8(4), offset=i8(5)),
                 uop3=macro_uop(uop=i16(483), size=i8(0), offset=i8(9))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(345), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(429), size=i8(1), offset=i8(3)),
                 uop3=macro_uop(uop=i16(483), size=i8(0), offset=i8(9))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(336), size=i8(1), offset=i8(3)),
                 uop2=macro_uop(uop=i16(430), size=i8(4), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(431), size=i8(4), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(380), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(386), size=i8(2), offset=i8(3)),
                 uop3=macro_uop(uop=i16(432), size=i8(4), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(433), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(433), size=i8(10), offset=i8(3)),
                 uop2=macro_uop(uop=i16(483), size=i8(0), offset=i8(9))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(434), size=i8(4), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(380), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(386), size=i8(2), offset=i8(3)),
                 uop3=macro_uop(uop=i16(435), size=i8(4), offset=i8(5))
             ),
             opcode_macro_expansion(
                 nuops=5,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop2=macro_uop(uop=i16(436), size=i8(4), offset=i8(5)),
                 uop3=macro_uop(uop=i16(488), size=i8(7), offset=i8(9)),
                 uop4=macro_uop(uop=i16(482), size=i8(0), offset=i8(9))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(437), size=i8(1), offset=i8(3)),
                 uop2=macro_uop(uop=i16(483), size=i8(0), offset=i8(9))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(438), size=i8(1), offset=i8(3)),
                 uop2=macro_uop(uop=i16(483), size=i8(0), offset=i8(9))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(190), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(191), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(381), size=i8(1), offset=i8(1)),
                 uop1=macro_uop(uop=i16(461), size=i8(1), offset=i8(2)),
                 uop2=macro_uop(uop=i16(461), size=i8(10), offset=i8(3)),
                 uop3=macro_uop(uop=i16(483), size=i8(0), offset=i8(4))
             ),
             opcode_macro_expansion(
                 nuops=4,
                 uop0=macro_uop(uop=i16(27), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(462), size=i8(1), offset=i8(1)),
                 uop2=macro_uop(uop=i16(462), size=i8(10), offset=i8(3)),
                 uop3=macro_uop(uop=i16(483), size=i8(0), offset=i8(4))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(194), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(195), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(196), size=i8(0), offset=i8(0))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(348), size=i8(0), offset=i8(1)),
                 uop1=macro_uop(uop=i16(490), size=i8(0), offset=i8(1)),
                 uop2=macro_uop(uop=i16(482), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(406), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(379), size=i8(0), offset=i8(3)),
                 uop2=macro_uop(uop=i16(493), size=i8(1), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(494), size=i8(1), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(495), size=i8(1), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(387), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(507), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=3,
                 uop0=macro_uop(uop=i16(400), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(390), size=i8(0), offset=i8(0)),
                 uop2=macro_uop(uop=i16(508), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(405), size=i8(2), offset=i8(1)),
                 uop1=macro_uop(uop=i16(487), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(204), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(205), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(401), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(511), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=1, uop0=macro_uop(uop=i16(207), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(404), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(512), size=i8(0), offset=i8(3))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(401), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(514), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(403), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(515), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(
                 nuops=2,
                 uop0=macro_uop(uop=i16(403), size=i8(0), offset=i8(0)),
                 uop1=macro_uop(uop=i16(516), size=i8(0), offset=i8(1))
             ),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion(),
             opcode_macro_expansion()
         ];
}

import from c {
    def _PyOpcode_num_popped(opcode: i32, oparg: i32) -> i32 {
        arg = i64(oparg);
        if opcode == i32(256) {
            return i32.wrap(0);
        }
        if opcode == i32(44) {
            return i32.wrap(2);
        }
        if opcode == i32(129) {
            return i32.wrap(2);
        }
        if opcode == i32(130) {
            return i32.wrap(2);
        }
        if opcode == i32(131) {
            return i32.wrap(2);
        }
        if opcode == i32(132) {
            return i32.wrap(2);
        }
        if opcode == i32(3) {
            return i32.wrap(2);
        }
        if opcode == i32(133) {
            return i32.wrap(2);
        }
        if opcode == i32(134) {
            return i32.wrap(2);
        }
        if opcode == i32(135) {
            return i32.wrap(2);
        }
        if opcode == i32(136) {
            return i32.wrap(2);
        }
        if opcode == i32(137) {
            return i32.wrap(2);
        }
        if opcode == i32(138) {
            return i32.wrap(2);
        }
        if opcode == i32(139) {
            return i32.wrap(2);
        }
        if opcode == i32(140) {
            return i32.wrap(2);
        }
        if opcode == i32(141) {
            return i32.wrap(2);
        }
        if opcode == i32(142) {
            return i32.wrap(2);
        }
        if opcode == i32(1) {
            return i32.wrap(3);
        }
        if opcode == i32(45) {
            return i32.wrap(2 + (arg & 1));
        }
        if opcode == i32(46) {
            return i32.wrap(arg);
        }
        if opcode == i32(47) {
            return i32.wrap(arg * 2);
        }
        if opcode == i32(48) {
            return i32.wrap(arg);
        }
        if opcode == i32(49) {
            return i32.wrap(arg);
        }
        if opcode == i32(50) {
            return i32.wrap(arg);
        }
        if opcode == i32(2) {
            return i32.wrap(2);
        }
        if opcode == i32(51) {
            return i32.wrap(arg);
        }
        if opcode == i32(0) {
            return i32.wrap(0);
        }
        if opcode == i32(52) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(143) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(144) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(145) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(146) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(147) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(148) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(149) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(4) {
            return i32.wrap(4);
        }
        if opcode == i32(53) {
            return i32.wrap(1);
        }
        if opcode == i32(54) {
            return i32.wrap(2);
        }
        if opcode == i32(150) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(55) {
            return i32.wrap(3 + arg);
        }
        if opcode == i32(151) {
            return i32.wrap(3 + arg);
        }
        if opcode == i32(152) {
            return i32.wrap(3 + arg);
        }
        if opcode == i32(153) {
            return i32.wrap(3 + arg);
        }
        if opcode == i32(154) {
            return i32.wrap(3);
        }
        if opcode == i32(155) {
            return i32.wrap(3);
        }
        if opcode == i32(156) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(157) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(158) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(159) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(160) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(161) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(162) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(163) {
            return i32.wrap(3);
        }
        if opcode == i32(164) {
            return i32.wrap(3);
        }
        if opcode == i32(165) {
            return i32.wrap(3);
        }
        if opcode == i32(5) {
            return i32.wrap(2);
        }
        if opcode == i32(6) {
            return i32.wrap(2);
        }
        if opcode == i32(7) {
            return i32.wrap(3);
        }
        if opcode == i32(56) {
            return i32.wrap(2);
        }
        if opcode == i32(166) {
            return i32.wrap(2);
        }
        if opcode == i32(167) {
            return i32.wrap(2);
        }
        if opcode == i32(168) {
            return i32.wrap(2);
        }
        if opcode == i32(57) {
            return i32.wrap(2);
        }
        if opcode == i32(169) {
            return i32.wrap(2);
        }
        if opcode == i32(170) {
            return i32.wrap(2);
        }
        if opcode == i32(58) {
            return i32.wrap(1);
        }
        if opcode == i32(59) {
            return i32.wrap(1 + (arg - 1));
        }
        if opcode == i32(60) {
            return i32.wrap(0);
        }
        if opcode == i32(61) {
            return i32.wrap(1);
        }
        if opcode == i32(62) {
            return i32.wrap(0);
        }
        if opcode == i32(63) {
            return i32.wrap(0);
        }
        if opcode == i32(64) {
            return i32.wrap(0);
        }
        if opcode == i32(65) {
            return i32.wrap(0);
        }
        if opcode == i32(8) {
            return i32.wrap(2);
        }
        if opcode == i32(66) {
            return i32.wrap(5 + (arg - 1));
        }
        if opcode == i32(67) {
            return i32.wrap(2 + (arg - 1));
        }
        if opcode == i32(68) {
            return i32.wrap(2);
        }
        if opcode == i32(9) {
            return i32.wrap(1);
        }
        if opcode == i32(10) {
            return i32.wrap(2);
        }
        if opcode == i32(255) {
            return i32.wrap(0);
        }
        if opcode == i32(11) {
            return i32.wrap(1);
        }
        if opcode == i32(69) {
            return i32.wrap(0);
        }
        if opcode == i32(12) {
            return i32.wrap(1);
        }
        if opcode == i32(13) {
            return i32.wrap(2);
        }
        if opcode == i32(70) {
            return i32.wrap(1);
        }
        if opcode == i32(171) {
            return i32.wrap(1);
        }
        if opcode == i32(172) {
            return i32.wrap(1);
        }
        if opcode == i32(173) {
            return i32.wrap(1);
        }
        if opcode == i32(174) {
            return i32.wrap(1);
        }
        if opcode == i32(14) {
            return i32.wrap(1);
        }
        if opcode == i32(15) {
            return i32.wrap(1);
        }
        if opcode == i32(71) {
            return i32.wrap(1);
        }
        if opcode == i32(16) {
            return i32.wrap(1);
        }
        if opcode == i32(18) {
            return i32.wrap(1);
        }
        if opcode == i32(19) {
            return i32.wrap(1);
        }
        if opcode == i32(72) {
            return i32.wrap(1);
        }
        if opcode == i32(73) {
            return i32.wrap(2);
        }
        if opcode == i32(250) {
            return i32.wrap(2 + arg);
        }
        if opcode == i32(252) {
            return i32.wrap(4);
        }
        if opcode == i32(251) {
            return i32.wrap(3 + arg);
        }
        if opcode == i32(248) {
            return i32.wrap(2);
        }
        if opcode == i32(234) {
            return i32.wrap(2);
        }
        if opcode == i32(236) {
            return i32.wrap(2);
        }
        if opcode == i32(237) {
            return i32.wrap(1);
        }
        if opcode == i32(238) {
            return i32.wrap(0);
        }
        if opcode == i32(253) {
            return i32.wrap(0);
        }
        if opcode == i32(239) {
            return i32.wrap(0);
        }
        if opcode == i32(254) {
            return i32.wrap(0);
        }
        if opcode == i32(249) {
            return i32.wrap(3);
        }
        if opcode == i32(240) {
            return i32.wrap(0);
        }
        if opcode == i32(235) {
            return i32.wrap(1);
        }
        if opcode == i32(242) {
            return i32.wrap(1);
        }
        if opcode == i32(243) {
            return i32.wrap(1);
        }
        if opcode == i32(244) {
            return i32.wrap(1);
        }
        if opcode == i32(241) {
            return i32.wrap(1);
        }
        if opcode == i32(245) {
            return i32.wrap(0);
        }
        if opcode == i32(246) {
            return i32.wrap(1);
        }
        if opcode == i32(247) {
            return i32.wrap(1);
        }
        if opcode == i32(20) {
            return i32.wrap(1);
        }
        if opcode == i32(74) {
            return i32.wrap(2);
        }
        if opcode == i32(257) {
            return i32.wrap(0);
        }
        if opcode == i32(75) {
            return i32.wrap(0);
        }
        if opcode == i32(175) {
            return i32.wrap(0);
        }
        if opcode == i32(76) {
            return i32.wrap(0);
        }
        if opcode == i32(176) {
            return i32.wrap(0);
        }
        if opcode == i32(77) {
            return i32.wrap(0);
        }
        if opcode == i32(258) {
            return i32.wrap(1);
        }
        if opcode == i32(259) {
            return i32.wrap(1);
        }
        if opcode == i32(260) {
            return i32.wrap(0);
        }
        if opcode == i32(78) {
            return i32.wrap(2 + (arg - 1));
        }
        if opcode == i32(79) {
            return i32.wrap(2 + (arg - 1));
        }
        if opcode == i32(80) {
            return i32.wrap(1);
        }
        if opcode == i32(177) {
            return i32.wrap(1);
        }
        if opcode == i32(178) {
            return i32.wrap(1);
        }
        if opcode == i32(179) {
            return i32.wrap(1);
        }
        if opcode == i32(180) {
            return i32.wrap(1);
        }
        if opcode == i32(181) {
            return i32.wrap(1);
        }
        if opcode == i32(182) {
            return i32.wrap(1);
        }
        if opcode == i32(183) {
            return i32.wrap(1);
        }
        if opcode == i32(184) {
            return i32.wrap(1);
        }
        if opcode == i32(185) {
            return i32.wrap(1);
        }
        if opcode == i32(186) {
            return i32.wrap(1);
        }
        if opcode == i32(187) {
            return i32.wrap(1);
        }
        if opcode == i32(188) {
            return i32.wrap(1);
        }
        if opcode == i32(189) {
            return i32.wrap(1);
        }
        if opcode == i32(21) {
            return i32.wrap(0);
        }
        if opcode == i32(261) {
            return i32.wrap(0);
        }
        if opcode == i32(81) {
            return i32.wrap(0);
        }
        if opcode == i32(82) {
            return i32.wrap(0);
        }
        if opcode == i32(190) {
            return i32.wrap(0);
        }
        if opcode == i32(191) {
            return i32.wrap(0);
        }
        if opcode == i32(83) {
            return i32.wrap(0);
        }
        if opcode == i32(84) {
            return i32.wrap(0);
        }
        if opcode == i32(85) {
            return i32.wrap(0);
        }
        if opcode == i32(86) {
            return i32.wrap(0);
        }
        if opcode == i32(87) {
            return i32.wrap(0);
        }
        if opcode == i32(88) {
            return i32.wrap(0);
        }
        if opcode == i32(89) {
            return i32.wrap(0);
        }
        if opcode == i32(90) {
            return i32.wrap(1);
        }
        if opcode == i32(91) {
            return i32.wrap(1);
        }
        if opcode == i32(92) {
            return i32.wrap(0);
        }
        if opcode == i32(192) {
            return i32.wrap(0);
        }
        if opcode == i32(193) {
            return i32.wrap(0);
        }
        if opcode == i32(22) {
            return i32.wrap(0);
        }
        if opcode == i32(93) {
            return i32.wrap(0);
        }
        if opcode == i32(94) {
            return i32.wrap(0);
        }
        if opcode == i32(95) {
            return i32.wrap(1);
        }
        if opcode == i32(96) {
            return i32.wrap(3);
        }
        if opcode == i32(194) {
            return i32.wrap(3);
        }
        if opcode == i32(195) {
            return i32.wrap(3);
        }
        if opcode == i32(97) {
            return i32.wrap(0);
        }
        if opcode == i32(23) {
            return i32.wrap(1);
        }
        if opcode == i32(98) {
            return i32.wrap(3 + (arg - 1));
        }
        if opcode == i32(99) {
            return i32.wrap(3);
        }
        if opcode == i32(24) {
            return i32.wrap(2);
        }
        if opcode == i32(25) {
            return i32.wrap(1);
        }
        if opcode == i32(26) {
            return i32.wrap(1);
        }
        if opcode == i32(27) {
            return i32.wrap(0);
        }
        if opcode == i32(28) {
            return i32.wrap(0);
        }
        if opcode == i32(262) {
            return i32.wrap(0);
        }
        if opcode == i32(29) {
            return i32.wrap(1);
        }
        if opcode == i32(30) {
            return i32.wrap(1);
        }
        if opcode == i32(100) {
            return i32.wrap(1);
        }
        if opcode == i32(101) {
            return i32.wrap(1);
        }
        if opcode == i32(102) {
            return i32.wrap(1);
        }
        if opcode == i32(103) {
            return i32.wrap(1);
        }
        if opcode == i32(31) {
            return i32.wrap(1);
        }
        if opcode == i32(32) {
            return i32.wrap(1);
        }
        if opcode == i32(33) {
            return i32.wrap(0);
        }
        if opcode == i32(104) {
            return i32.wrap(arg);
        }
        if opcode == i32(105) {
            return i32.wrap(1 + arg);
        }
        if opcode == i32(17) {
            return i32.wrap(0);
        }
        if opcode == i32(128) {
            return i32.wrap(0);
        }
        if opcode == i32(196) {
            return i32.wrap(0);
        }
        if opcode == i32(34) {
            return i32.wrap(0);
        }
        if opcode == i32(35) {
            return i32.wrap(1);
        }
        if opcode == i32(106) {
            return i32.wrap(2);
        }
        if opcode == i32(197) {
            return i32.wrap(2);
        }
        if opcode == i32(36) {
            return i32.wrap(0);
        }
        if opcode == i32(263) {
            return i32.wrap(0);
        }
        if opcode == i32(264) {
            return i32.wrap(0);
        }
        if opcode == i32(265) {
            return i32.wrap(0);
        }
        if opcode == i32(107) {
            return i32.wrap(2 + (arg - 1));
        }
        if opcode == i32(108) {
            return i32.wrap(2);
        }
        if opcode == i32(109) {
            return i32.wrap(2 + (arg - 1));
        }
        if opcode == i32(110) {
            return i32.wrap(2);
        }
        if opcode == i32(198) {
            return i32.wrap(2);
        }
        if opcode == i32(199) {
            return i32.wrap(2);
        }
        if opcode == i32(200) {
            return i32.wrap(2);
        }
        if opcode == i32(111) {
            return i32.wrap(1);
        }
        if opcode == i32(112) {
            return i32.wrap(1);
        }
        if opcode == i32(113) {
            return i32.wrap(1);
        }
        if opcode == i32(266) {
            return i32.wrap(1);
        }
        if opcode == i32(114) {
            return i32.wrap(2);
        }
        if opcode == i32(115) {
            return i32.wrap(1);
        }
        if opcode == i32(116) {
            return i32.wrap(1);
        }
        if opcode == i32(37) {
            return i32.wrap(4);
        }
        if opcode == i32(38) {
            return i32.wrap(3);
        }
        if opcode == i32(201) {
            return i32.wrap(3);
        }
        if opcode == i32(202) {
            return i32.wrap(3);
        }
        if opcode == i32(117) {
            return i32.wrap(2 + (arg - 2));
        }
        if opcode == i32(39) {
            return i32.wrap(1);
        }
        if opcode == i32(203) {
            return i32.wrap(1);
        }
        if opcode == i32(204) {
            return i32.wrap(1);
        }
        if opcode == i32(205) {
            return i32.wrap(1);
        }
        if opcode == i32(206) {
            return i32.wrap(1);
        }
        if opcode == i32(207) {
            return i32.wrap(1);
        }
        if opcode == i32(208) {
            return i32.wrap(1);
        }
        if opcode == i32(40) {
            return i32.wrap(1);
        }
        if opcode == i32(41) {
            return i32.wrap(1);
        }
        if opcode == i32(42) {
            return i32.wrap(1);
        }
        if opcode == i32(118) {
            return i32.wrap(1);
        }
        if opcode == i32(119) {
            return i32.wrap(1);
        }
        if opcode == i32(209) {
            return i32.wrap(1);
        }
        if opcode == i32(210) {
            return i32.wrap(1);
        }
        if opcode == i32(211) {
            return i32.wrap(1);
        }
        if opcode == i32(43) {
            return i32.wrap(5);
        }
        if opcode == i32(120) {
            return i32.wrap(1);
        }
        return i32(-1);
    }
}

import from c {
    def _PyOpcode_num_pushed(opcode: i32, oparg: i32) -> i32 {
        arg = i64(oparg);
        if opcode == i32(256) {
            return i32.wrap(0);
        }
        if opcode == i32(44) {
            return i32.wrap(1);
        }
        if opcode == i32(129) {
            return i32.wrap(1);
        }
        if opcode == i32(130) {
            return i32.wrap(1);
        }
        if opcode == i32(131) {
            return i32.wrap(1);
        }
        if opcode == i32(132) {
            return i32.wrap(1);
        }
        if opcode == i32(3) {
            return i32.wrap(0);
        }
        if opcode == i32(133) {
            return i32.wrap(1);
        }
        if opcode == i32(134) {
            return i32.wrap(1);
        }
        if opcode == i32(135) {
            return i32.wrap(1);
        }
        if opcode == i32(136) {
            return i32.wrap(0);
        }
        if opcode == i32(137) {
            return i32.wrap(1);
        }
        if opcode == i32(138) {
            return i32.wrap(1);
        }
        if opcode == i32(139) {
            return i32.wrap(1);
        }
        if opcode == i32(140) {
            return i32.wrap(1);
        }
        if opcode == i32(141) {
            return i32.wrap(1);
        }
        if opcode == i32(142) {
            return i32.wrap(1);
        }
        if opcode == i32(1) {
            return i32.wrap(1);
        }
        if opcode == i32(45) {
            return i32.wrap(1);
        }
        if opcode == i32(46) {
            return i32.wrap(1);
        }
        if opcode == i32(47) {
            return i32.wrap(1);
        }
        if opcode == i32(48) {
            return i32.wrap(1);
        }
        if opcode == i32(49) {
            return i32.wrap(1);
        }
        if opcode == i32(50) {
            return i32.wrap(1);
        }
        if opcode == i32(2) {
            return i32.wrap(1);
        }
        if opcode == i32(51) {
            return i32.wrap(1);
        }
        if opcode == i32(0) {
            return i32.wrap(0);
        }
        if opcode == i32(52) {
            return i32.wrap(1);
        }
        if opcode == i32(143) {
            return i32.wrap(0);
        }
        if opcode == i32(144) {
            return i32.wrap(0);
        }
        if opcode == i32(145) {
            return i32.wrap(0);
        }
        if opcode == i32(146) {
            return i32.wrap(1);
        }
        if opcode == i32(147) {
            return i32.wrap(1);
        }
        if opcode == i32(148) {
            return i32.wrap(1);
        }
        if opcode == i32(149) {
            return i32.wrap(1);
        }
        if opcode == i32(4) {
            return i32.wrap(1);
        }
        if opcode == i32(53) {
            return i32.wrap(1);
        }
        if opcode == i32(54) {
            return i32.wrap(1);
        }
        if opcode == i32(150) {
            return i32.wrap(1);
        }
        if opcode == i32(55) {
            return i32.wrap(1);
        }
        if opcode == i32(151) {
            return i32.wrap(0);
        }
        if opcode == i32(152) {
            return i32.wrap(1);
        }
        if opcode == i32(153) {
            return i32.wrap(0);
        }
        if opcode == i32(154) {
            return i32.wrap(1);
        }
        if opcode == i32(155) {
            return i32.wrap(0);
        }
        if opcode == i32(156) {
            return i32.wrap(1);
        }
        if opcode == i32(157) {
            return i32.wrap(1);
        }
        if opcode == i32(158) {
            return i32.wrap(1);
        }
        if opcode == i32(159) {
            return i32.wrap(1);
        }
        if opcode == i32(160) {
            return i32.wrap(1);
        }
        if opcode == i32(161) {
            return i32.wrap(0);
        }
        if opcode == i32(162) {
            return i32.wrap(0);
        }
        if opcode == i32(163) {
            return i32.wrap(1);
        }
        if opcode == i32(164) {
            return i32.wrap(1);
        }
        if opcode == i32(165) {
            return i32.wrap(1);
        }
        if opcode == i32(5) {
            return i32.wrap(2);
        }
        if opcode == i32(6) {
            return i32.wrap(2);
        }
        if opcode == i32(7) {
            return i32.wrap(2);
        }
        if opcode == i32(56) {
            return i32.wrap(1);
        }
        if opcode == i32(166) {
            return i32.wrap(1);
        }
        if opcode == i32(167) {
            return i32.wrap(1);
        }
        if opcode == i32(168) {
            return i32.wrap(1);
        }
        if opcode == i32(57) {
            return i32.wrap(1);
        }
        if opcode == i32(169) {
            return i32.wrap(1);
        }
        if opcode == i32(170) {
            return i32.wrap(1);
        }
        if opcode == i32(58) {
            return i32.wrap(1);
        }
        if opcode == i32(59) {
            return i32.wrap(2 + (arg - 1));
        }
        if opcode == i32(60) {
            return i32.wrap(0);
        }
        if opcode == i32(61) {
            return i32.wrap(0);
        }
        if opcode == i32(62) {
            return i32.wrap(0);
        }
        if opcode == i32(63) {
            return i32.wrap(0);
        }
        if opcode == i32(64) {
            return i32.wrap(0);
        }
        if opcode == i32(65) {
            return i32.wrap(0);
        }
        if opcode == i32(8) {
            return i32.wrap(0);
        }
        if opcode == i32(66) {
            return i32.wrap(4 + (arg - 1));
        }
        if opcode == i32(67) {
            return i32.wrap(1 + (arg - 1));
        }
        if opcode == i32(68) {
            return i32.wrap(0);
        }
        if opcode == i32(9) {
            return i32.wrap(0);
        }
        if opcode == i32(10) {
            return i32.wrap(1);
        }
        if opcode == i32(255) {
            return i32.wrap(0);
        }
        if opcode == i32(11) {
            return i32.wrap(0);
        }
        if opcode == i32(69) {
            return i32.wrap(0);
        }
        if opcode == i32(12) {
            return i32.wrap(1);
        }
        if opcode == i32(13) {
            return i32.wrap(1);
        }
        if opcode == i32(70) {
            return i32.wrap(2);
        }
        if opcode == i32(171) {
            return i32.wrap(1);
        }
        if opcode == i32(172) {
            return i32.wrap(2);
        }
        if opcode == i32(173) {
            return i32.wrap(2);
        }
        if opcode == i32(174) {
            return i32.wrap(2);
        }
        if opcode == i32(14) {
            return i32.wrap(1);
        }
        if opcode == i32(15) {
            return i32.wrap(2);
        }
        if opcode == i32(71) {
            return i32.wrap(1);
        }
        if opcode == i32(16) {
            return i32.wrap(1);
        }
        if opcode == i32(18) {
            return i32.wrap(2);
        }
        if opcode == i32(19) {
            return i32.wrap(1);
        }
        if opcode == i32(72) {
            return i32.wrap(2);
        }
        if opcode == i32(73) {
            return i32.wrap(1);
        }
        if opcode == i32(250) {
            return i32.wrap(1);
        }
        if opcode == i32(252) {
            return i32.wrap(1);
        }
        if opcode == i32(251) {
            return i32.wrap(1);
        }
        if opcode == i32(248) {
            return i32.wrap(0);
        }
        if opcode == i32(234) {
            return i32.wrap(1);
        }
        if opcode == i32(236) {
            return i32.wrap(1);
        }
        if opcode == i32(237) {
            return i32.wrap(2);
        }
        if opcode == i32(238) {
            return i32.wrap(0);
        }
        if opcode == i32(253) {
            return i32.wrap(0);
        }
        if opcode == i32(239) {
            return i32.wrap(0);
        }
        if opcode == i32(254) {
            return i32.wrap(0);
        }
        if opcode == i32(249) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(240) {
            return i32.wrap(0);
        }
        if opcode == i32(235) {
            return i32.wrap(0);
        }
        if opcode == i32(242) {
            return i32.wrap(0);
        }
        if opcode == i32(243) {
            return i32.wrap(0);
        }
        if opcode == i32(244) {
            return i32.wrap(0);
        }
        if opcode == i32(241) {
            return i32.wrap(0);
        }
        if opcode == i32(245) {
            return i32.wrap(0);
        }
        if opcode == i32(246) {
            return i32.wrap(1);
        }
        if opcode == i32(247) {
            return i32.wrap(1);
        }
        if opcode == i32(20) {
            return i32.wrap(0);
        }
        if opcode == i32(74) {
            return i32.wrap(1);
        }
        if opcode == i32(257) {
            return i32.wrap(0);
        }
        if opcode == i32(75) {
            return i32.wrap(0);
        }
        if opcode == i32(175) {
            return i32.wrap(0);
        }
        if opcode == i32(76) {
            return i32.wrap(0);
        }
        if opcode == i32(176) {
            return i32.wrap(0);
        }
        if opcode == i32(77) {
            return i32.wrap(0);
        }
        if opcode == i32(258) {
            return i32.wrap(1);
        }
        if opcode == i32(259) {
            return i32.wrap(1);
        }
        if opcode == i32(260) {
            return i32.wrap(0);
        }
        if opcode == i32(78) {
            return i32.wrap(1 + (arg - 1));
        }
        if opcode == i32(79) {
            return i32.wrap(1 + (arg - 1));
        }
        if opcode == i32(80) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(177) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(178) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(179) {
            return i32.wrap(1);
        }
        if opcode == i32(180) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(181) {
            return i32.wrap(2);
        }
        if opcode == i32(182) {
            return i32.wrap(2);
        }
        if opcode == i32(183) {
            return i32.wrap(2);
        }
        if opcode == i32(184) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(185) {
            return i32.wrap(1);
        }
        if opcode == i32(186) {
            return i32.wrap(1);
        }
        if opcode == i32(187) {
            return i32.wrap(0);
        }
        if opcode == i32(188) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(189) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(21) {
            return i32.wrap(1);
        }
        if opcode == i32(261) {
            return i32.wrap(1);
        }
        if opcode == i32(81) {
            return i32.wrap(1);
        }
        if opcode == i32(82) {
            return i32.wrap(1);
        }
        if opcode == i32(190) {
            return i32.wrap(1);
        }
        if opcode == i32(191) {
            return i32.wrap(1);
        }
        if opcode == i32(83) {
            return i32.wrap(1);
        }
        if opcode == i32(84) {
            return i32.wrap(1);
        }
        if opcode == i32(85) {
            return i32.wrap(1);
        }
        if opcode == i32(86) {
            return i32.wrap(1);
        }
        if opcode == i32(87) {
            return i32.wrap(2);
        }
        if opcode == i32(88) {
            return i32.wrap(1);
        }
        if opcode == i32(89) {
            return i32.wrap(2);
        }
        if opcode == i32(90) {
            return i32.wrap(1);
        }
        if opcode == i32(91) {
            return i32.wrap(1);
        }
        if opcode == i32(92) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(192) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(193) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(22) {
            return i32.wrap(1);
        }
        if opcode == i32(93) {
            return i32.wrap(1);
        }
        if opcode == i32(94) {
            return i32.wrap(1);
        }
        if opcode == i32(95) {
            return i32.wrap(2);
        }
        if opcode == i32(96) {
            return i32.wrap(1 + (arg & 1));
        }
        if opcode == i32(194) {
            return i32.wrap(1);
        }
        if opcode == i32(195) {
            return i32.wrap(2);
        }
        if opcode == i32(97) {
            return i32.wrap(0);
        }
        if opcode == i32(23) {
            return i32.wrap(1);
        }
        if opcode == i32(98) {
            return i32.wrap(1 + (arg - 1));
        }
        if opcode == i32(99) {
            return i32.wrap(1);
        }
        if opcode == i32(24) {
            return i32.wrap(3);
        }
        if opcode == i32(25) {
            return i32.wrap(2);
        }
        if opcode == i32(26) {
            return i32.wrap(2);
        }
        if opcode == i32(27) {
            return i32.wrap(0);
        }
        if opcode == i32(28) {
            return i32.wrap(0);
        }
        if opcode == i32(262) {
            return i32.wrap(0);
        }
        if opcode == i32(29) {
            return i32.wrap(0);
        }
        if opcode == i32(30) {
            return i32.wrap(0);
        }
        if opcode == i32(100) {
            return i32.wrap(0);
        }
        if opcode == i32(101) {
            return i32.wrap(0);
        }
        if opcode == i32(102) {
            return i32.wrap(0);
        }
        if opcode == i32(103) {
            return i32.wrap(0);
        }
        if opcode == i32(31) {
            return i32.wrap(0);
        }
        if opcode == i32(32) {
            return i32.wrap(2);
        }
        if opcode == i32(33) {
            return i32.wrap(1);
        }
        if opcode == i32(104) {
            return i32.wrap(0);
        }
        if opcode == i32(105) {
            return i32.wrap(arg);
        }
        if opcode == i32(17) {
            return i32.wrap(0);
        }
        if opcode == i32(128) {
            return i32.wrap(0);
        }
        if opcode == i32(196) {
            return i32.wrap(0);
        }
        if opcode == i32(34) {
            return i32.wrap(1);
        }
        if opcode == i32(35) {
            return i32.wrap(1);
        }
        if opcode == i32(106) {
            return i32.wrap(2);
        }
        if opcode == i32(197) {
            return i32.wrap(1);
        }
        if opcode == i32(36) {
            return i32.wrap(0);
        }
        if opcode == i32(263) {
            return i32.wrap(2);
        }
        if opcode == i32(264) {
            return i32.wrap(1);
        }
        if opcode == i32(265) {
            return i32.wrap(1);
        }
        if opcode == i32(107) {
            return i32.wrap(1 + (arg - 1));
        }
        if opcode == i32(108) {
            return i32.wrap(1);
        }
        if opcode == i32(109) {
            return i32.wrap(1 + (arg - 1));
        }
        if opcode == i32(110) {
            return i32.wrap(0);
        }
        if opcode == i32(198) {
            return i32.wrap(0);
        }
        if opcode == i32(199) {
            return i32.wrap(0);
        }
        if opcode == i32(200) {
            return i32.wrap(0);
        }
        if opcode == i32(111) {
            return i32.wrap(0);
        }
        if opcode == i32(112) {
            return i32.wrap(0);
        }
        if opcode == i32(113) {
            return i32.wrap(1);
        }
        if opcode == i32(266) {
            return i32.wrap(0);
        }
        if opcode == i32(114) {
            return i32.wrap(0);
        }
        if opcode == i32(115) {
            return i32.wrap(0);
        }
        if opcode == i32(116) {
            return i32.wrap(0);
        }
        if opcode == i32(37) {
            return i32.wrap(0);
        }
        if opcode == i32(38) {
            return i32.wrap(0);
        }
        if opcode == i32(201) {
            return i32.wrap(0);
        }
        if opcode == i32(202) {
            return i32.wrap(0);
        }
        if opcode == i32(117) {
            return i32.wrap(2 + (arg - 2));
        }
        if opcode == i32(39) {
            return i32.wrap(1);
        }
        if opcode == i32(203) {
            return i32.wrap(1);
        }
        if opcode == i32(204) {
            return i32.wrap(1);
        }
        if opcode == i32(205) {
            return i32.wrap(1);
        }
        if opcode == i32(206) {
            return i32.wrap(1);
        }
        if opcode == i32(207) {
            return i32.wrap(1);
        }
        if opcode == i32(208) {
            return i32.wrap(1);
        }
        if opcode == i32(40) {
            return i32.wrap(1);
        }
        if opcode == i32(41) {
            return i32.wrap(1);
        }
        if opcode == i32(42) {
            return i32.wrap(1);
        }
        if opcode == i32(118) {
            return i32.wrap(1 + (arg & 0xFF) + (arg >> 8));
        }
        if opcode == i32(119) {
            return i32.wrap(arg);
        }
        if opcode == i32(209) {
            return i32.wrap(arg);
        }
        if opcode == i32(210) {
            return i32.wrap(arg);
        }
        if opcode == i32(211) {
            return i32.wrap(2);
        }
        if opcode == i32(43) {
            return i32.wrap(6);
        }
        if opcode == i32(120) {
            return i32.wrap(1);
        }
        return i32(-1);
    }
}
