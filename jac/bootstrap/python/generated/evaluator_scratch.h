/* Generated typed scratch storage, CPython 3.14.6; PSF licensed. */
union JacPyVMScratch {
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_lhs;
        _PyStackRef s3_rhs;
        _PyStackRef s4_res;
        uint16_t s5_counter;
        PyObject * s6_lhs_o;
        PyObject * s7_rhs_o;
        PyObject * s8_res_o;
        _PyStackRef s9_tmp;
    } op_BINARY_OP;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        double s10_dres;
    } op_BINARY_OP_ADD_FLOAT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        PyObject * s10_res_o;
    } op_BINARY_OP_ADD_INT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_nos;
        _PyStackRef s4_left;
        _PyStackRef s5_right;
        _PyStackRef s6_res;
        PyObject * s7_value_o;
        PyObject * s8_o;
        PyObject * s9_left_o;
        PyObject * s10_right_o;
        PyObject * s11_res_o;
    } op_BINARY_OP_ADD_UNICODE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_left;
        _PyStackRef s3_right;
        _PyStackRef s4_res;
        PyObject * s5_descr;
        PyObject * s6_left_o;
        PyObject * s7_right_o;
        _PyBinaryOpSpecializationDescr * s8_d;
        int s9_res;
        PyObject * s10_descr;
        PyObject * s11_left_o;
        PyObject * s12_right_o;
        _PyBinaryOpSpecializationDescr * s13_d;
        PyObject * s14_res_o;
        _PyStackRef s15_tmp;
    } op_BINARY_OP_EXTEND;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_nos;
        _PyStackRef s4_left;
        _PyStackRef s5_right;
        PyObject * s6_value_o;
        PyObject * s7_o;
        PyObject * s8_left_o;
        int s9_next_oparg;
        _PyStackRef * s10_target_local;
        PyObject * s11_temp;
        PyObject * s12_right_o;
    } op_BINARY_OP_INPLACE_ADD_UNICODE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        double s10_dres;
    } op_BINARY_OP_MULTIPLY_FLOAT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        PyObject * s10_res_o;
    } op_BINARY_OP_MULTIPLY_INT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_nos;
        _PyStackRef s3_dict_st;
        _PyStackRef s4_sub_st;
        _PyStackRef s5_res;
        PyObject * s6_o;
        PyObject * s7_sub;
        PyObject * s8_dict;
        PyObject * s9_res_o;
        int s10_rc;
        _PyStackRef s11_tmp;
    } op_BINARY_OP_SUBSCR_DICT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_container;
        _PyStackRef s3_getitem;
        _PyStackRef s4_sub;
        _PyInterpreterFrame * s5_new_frame;
        PyTypeObject * s6_tp;
        PyHeapTypeObject * s7_ht;
        PyObject * s8_getitem_o;
        uint32_t s9_cached_version;
        PyCodeObject * s10_code;
        _PyInterpreterFrame * s11_temp;
    } op_BINARY_OP_SUBSCR_GETITEM;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_nos;
        _PyStackRef s4_list_st;
        _PyStackRef s5_sub_st;
        _PyStackRef s6_res;
        PyObject * s7_value_o;
        PyObject * s8_o;
        PyObject * s9_sub;
        PyObject * s10_list;
        Py_ssize_t s11_index;
        PyObject * s12_res_o;
        _PyStackRef s13_tmp;
    } op_BINARY_OP_SUBSCR_LIST_INT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_tos;
        _PyStackRef s3_nos;
        _PyStackRef s4_list_st;
        _PyStackRef s5_sub_st;
        _PyStackRef s6_res;
        PyObject * s7_o;
        PyObject * s8_o;
        PyObject * s9_sub;
        PyObject * s10_list;
        PyObject * s11_res_o;
        _PyStackRef s12_tmp;
    } op_BINARY_OP_SUBSCR_LIST_SLICE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_nos;
        _PyStackRef s4_str_st;
        _PyStackRef s5_sub_st;
        _PyStackRef s6_res;
        PyObject * s7_value_o;
        PyObject * s8_o;
        PyObject * s9_sub;
        PyObject * s10_str;
        Py_ssize_t s11_index;
        Py_UCS4 s12_c;
        PyObject * s13_res_o;
    } op_BINARY_OP_SUBSCR_STR_INT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_nos;
        _PyStackRef s4_tuple_st;
        _PyStackRef s5_sub_st;
        _PyStackRef s6_res;
        PyObject * s7_value_o;
        PyObject * s8_o;
        PyObject * s9_sub;
        PyObject * s10_tuple;
        Py_ssize_t s11_index;
        PyObject * s12_res_o;
        _PyStackRef s13_tmp;
    } op_BINARY_OP_SUBSCR_TUPLE_INT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        double s10_dres;
    } op_BINARY_OP_SUBTRACT_FLOAT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        PyObject * s10_res_o;
    } op_BINARY_OP_SUBTRACT_INT;
    struct {
        unsigned char empty;
        _PyStackRef s1_container;
        _PyStackRef s2_start;
        _PyStackRef s3_stop;
        _PyStackRef s4_res;
        PyObject * s5_slice;
        PyObject * s6_res_o;
    } op_BINARY_SLICE;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_str;
        _PyStackRef * s3_format;
        _PyStackRef s4_interpolation;
        PyObject * s5_value_o;
        PyObject * s6_str_o;
        int s7_conversion;
        PyObject * s8_format_o;
        PyObject * s9_interpolation_o;
    } op_BUILD_INTERPOLATION;
    struct {
        unsigned char empty;
        _PyStackRef * s1_values;
        _PyStackRef s2_list;
        PyObject * s3_list_o;
    } op_BUILD_LIST;
    struct {
        unsigned char empty;
        _PyStackRef * s1_values;
        _PyStackRef s2_map;
        PyObject * s3_values_o_temp[ 11 ];
        PyObject * * s4_values_o;
        _PyStackRef s5_tmp;
        int s6__i;
        PyObject * s7_map_o;
        _PyStackRef s8_tmp;
        int s9__i;
    } op_BUILD_MAP;
    struct {
        unsigned char empty;
        _PyStackRef * s1_values;
        _PyStackRef s2_set;
        PyObject * s3_set_o;
        _PyStackRef s4_tmp;
        int s5__i;
        int s6_err;
        Py_ssize_t s7_i;
        _PyStackRef s8_value;
    } op_BUILD_SET;
    struct {
        unsigned char empty;
        _PyStackRef * s1_args;
        _PyStackRef s2_slice;
        PyObject * s3_start_o;
        PyObject * s4_stop_o;
        PyObject * s5_step_o;
        PyObject * s6_slice_o;
        _PyStackRef s7_tmp;
        int s8__i;
    } op_BUILD_SLICE;
    struct {
        unsigned char empty;
        _PyStackRef * s1_pieces;
        _PyStackRef s2_str;
        PyObject * s3_pieces_o_temp[ 11 ];
        PyObject * * s4_pieces_o;
        _PyStackRef s5_tmp;
        int s6__i;
        PyObject * s7_str_o;
        _PyStackRef s8_tmp;
        int s9__i;
    } op_BUILD_STRING;
    struct {
        unsigned char empty;
        _PyStackRef s1_strings;
        _PyStackRef s2_interpolations;
        _PyStackRef s3_template;
        PyObject * s4_strings_o;
        PyObject * s5_interpolations_o;
        PyObject * s6_template_o;
    } op_BUILD_TEMPLATE;
    struct {
        unsigned char empty;
        _PyStackRef * s1_values;
        _PyStackRef s2_tup;
        PyObject * s3_tup_o;
    } op_BUILD_TUPLE;
    struct {
        unsigned char empty;
    } op_CACHE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        uint16_t s6_counter;
        PyObject * s7_callable_o;
        PyObject * s8_self;
        PyObject * s9_method;
        _PyStackRef s10_temp;
        PyObject * s11_callable_o;
        int s12_total_args;
        _PyStackRef * s13_arguments;
        int s14_code_flags;
        PyObject * s15_locals;
        _PyInterpreterFrame * s16_new_frame;
        PyObject * s17_args_o_temp[ 11 ];
        PyObject * * s18_args_o;
        _PyStackRef s19_tmp;
        int s20__i;
        PyObject * s21_res_o;
        PyObject * s22_arg;
        int s23_err;
        _PyStackRef s24_tmp;
        int s25__i;
        int s26_err;
    } op_CALL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef s4_init;
        _PyStackRef s5_self;
        _PyStackRef * s6_args;
        _PyInterpreterFrame * s7_init_frame;
        _PyInterpreterFrame * s8_new_frame;
        uint32_t s9_type_version;
        PyObject * s10_callable_o;
        PyTypeObject * s11_tp;
        PyHeapTypeObject * s12_cls;
        PyFunctionObject * s13_init_func;
        PyCodeObject * s14_code;
        PyObject * s15_self_o;
        _PyStackRef s16_temp;
        _PyInterpreterFrame * s17_shim;
        _PyInterpreterFrame * s18_temp;
        _PyInterpreterFrame * s19_temp;
    } op_CALL_ALLOC_AND_ENTER_INIT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_null;
        _PyStackRef s4_self_or_null;
        _PyStackRef * s5_args;
        _PyInterpreterFrame * s6_new_frame;
        PyObject * s7_callable_o;
        _PyStackRef s8_temp;
        uint32_t s9_func_version;
        PyObject * s10_callable_o;
        PyFunctionObject * s11_func;
        PyObject * s12_callable_o;
        PyFunctionObject * s13_func;
        PyCodeObject * s14_code;
        PyObject * s15_callable_o;
        PyFunctionObject * s16_func;
        PyCodeObject * s17_code;
        int s18_has_self;
        _PyStackRef * s19_first_non_self_local;
        int s20_i;
        _PyInterpreterFrame * s21_temp;
    } op_CALL_BOUND_METHOD_EXACT_ARGS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_null;
        _PyStackRef s4_self_or_null;
        _PyStackRef * s5_args;
        _PyInterpreterFrame * s6_new_frame;
        uint32_t s7_func_version;
        PyObject * s8_callable_o;
        PyObject * s9_func;
        PyObject * s10_callable_o;
        _PyStackRef s11_temp;
        PyObject * s12_callable_o;
        int s13_total_args;
        int s14_code_flags;
        PyObject * s15_locals;
        _PyInterpreterFrame * s16_temp;
        _PyInterpreterFrame * s17_temp;
    } op_CALL_BOUND_METHOD_GENERAL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        PyTypeObject * s7_tp;
        int s8_total_args;
        _PyStackRef * s9_arguments;
        PyObject * s10_args_o_temp[ 11 ];
        PyObject * * s11_args_o;
        _PyStackRef s12_tmp;
        int s13__i;
        PyObject * s14_res_o;
        _PyStackRef s15_tmp;
        int s16__i;
        int s17_err;
    } op_CALL_BUILTIN_CLASS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        _PyStackRef * s8_arguments;
        PyCFunction s9_cfunc;
        PyObject * s10_args_o_temp[ 11 ];
        PyObject * * s11_args_o;
        _PyStackRef s12_tmp;
        int s13__i;
        PyObject * s14_res_o;
        _PyStackRef s15_tmp;
        int s16__i;
        int s17_err;
    } op_CALL_BUILTIN_FAST;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        _PyStackRef * s8_arguments;
        PyCFunctionFastWithKeywords s9_cfunc;
        PyObject * s10_args_o_temp[ 11 ];
        PyObject * * s11_args_o;
        _PyStackRef s12_tmp;
        int s13__i;
        PyObject * s14_res_o;
        _PyStackRef s15_tmp;
        int s16__i;
        int s17_err;
    } op_CALL_BUILTIN_FAST_WITH_KEYWORDS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        PyCFunction s8_cfunc;
        _PyStackRef s9_arg;
        PyObject * s10_res_o;
        int s11_err;
    } op_CALL_BUILTIN_O;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_func;
        _PyStackRef s3_callargs;
        _PyStackRef s4_func_st;
        _PyStackRef s5_null;
        _PyStackRef s6_callargs_st;
        _PyStackRef s7_kwargs_st;
        _PyStackRef s8_result;
        PyObject * s9_callargs_o;
        int s10_err;
        PyObject * s11_tuple_o;
        _PyStackRef s12_temp;
        PyObject * s13_func;
        PyObject * s14_result_o;
        PyObject * s15_callargs;
        PyObject * s16_kwargs;
        PyObject * s17_arg;
        int s18_err;
        int s19_err;
        PyObject * s20_callargs;
        PyObject * s21_kwargs;
        Py_ssize_t s22_nargs;
        int s23_code_flags;
        PyObject * s24_locals;
        _PyInterpreterFrame * s25_new_frame;
        PyObject * s26_callargs;
        PyObject * s27_kwargs;
        int s28_err;
    } op_CALL_FUNCTION_EX;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_res;
        PyObject * s3_res_o;
    } op_CALL_INTRINSIC_1;
    struct {
        unsigned char empty;
        _PyStackRef s1_value2_st;
        _PyStackRef s2_value1_st;
        _PyStackRef s3_res;
        PyObject * s4_value1;
        PyObject * s5_value2;
        PyObject * s6_res_o;
        _PyStackRef s7_tmp;
    } op_CALL_INTRINSIC_2;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        _PyStackRef * s8_arguments;
        PyInterpreterState * s9_interp;
        _PyStackRef s10_cls_stackref;
        _PyStackRef s11_inst_stackref;
        int s12_retval;
        _PyStackRef s13_tmp;
        int s14__i;
    } op_CALL_ISINSTANCE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_kwnames;
        _PyStackRef s6_res;
        uint16_t s7_counter;
        PyObject * s8_callable_o;
        PyObject * s9_self;
        PyObject * s10_method;
        _PyStackRef s11_temp;
        PyObject * s12_callable_o;
        PyObject * s13_kwnames_o;
        int s14_total_args;
        _PyStackRef * s15_arguments;
        int s16_positional_args;
        int s17_code_flags;
        PyObject * s18_locals;
        _PyInterpreterFrame * s19_new_frame;
        PyObject * s20_args_o_temp[ 11 ];
        PyObject * * s21_args_o;
        _PyStackRef s22_tmp;
        int s23__i;
        PyObject * s24_res_o;
        PyObject * s25_arg;
        int s26_err;
        _PyStackRef s27_tmp;
        int s28__i;
    } op_CALL_KW;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_null;
        _PyStackRef s4_self_or_null;
        _PyStackRef * s5_args;
        _PyStackRef s6_kwnames;
        _PyInterpreterFrame * s7_new_frame;
        uint32_t s8_func_version;
        PyObject * s9_callable_o;
        PyObject * s10_func;
        _PyStackRef s11_callable_s;
        PyObject * s12_callable_o;
        PyObject * s13_callable_o;
        int s14_total_args;
        _PyStackRef * s15_arguments;
        PyObject * s16_kwnames_o;
        int s17_positional_args;
        int s18_code_flags;
        PyObject * s19_locals;
        _PyInterpreterFrame * s20_temp;
        _PyInterpreterFrame * s21_temp;
    } op_CALL_KW_BOUND_METHOD;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_kwnames;
        _PyStackRef s6_res;
        PyObject * s7_callable_o;
        PyObject * s8_callable_o;
        int s9_total_args;
        _PyStackRef * s10_arguments;
        PyObject * s11_args_o_temp[ 11 ];
        PyObject * * s12_args_o;
        _PyStackRef s13_tmp;
        int s14__i;
        PyObject * s15_kwnames_o;
        int s16_positional_args;
        PyObject * s17_res_o;
        _PyStackRef s18_tmp;
        int s19__i;
        int s20_err;
    } op_CALL_KW_NON_PY;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_kwnames;
        _PyInterpreterFrame * s6_new_frame;
        uint32_t s7_func_version;
        PyObject * s8_callable_o;
        PyFunctionObject * s9_func;
        PyObject * s10_callable_o;
        int s11_total_args;
        _PyStackRef * s12_arguments;
        PyObject * s13_kwnames_o;
        int s14_positional_args;
        int s15_code_flags;
        PyObject * s16_locals;
        _PyInterpreterFrame * s17_temp;
        _PyInterpreterFrame * s18_temp;
    } op_CALL_KW_PY;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_null;
        _PyStackRef s3_callable;
        _PyStackRef s4_arg;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        PyInterpreterState * s7_interp;
        PyObject * s8_arg_o;
        Py_ssize_t s9_len_i;
        PyObject * s10_res_o;
    } op_CALL_LEN;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self;
        _PyStackRef s4_arg;
        PyObject * s5_callable_o;
        PyObject * s6_self_o;
        PyInterpreterState * s7_interp;
        int s8_err;
    } op_CALL_LIST_APPEND;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        _PyStackRef * s8_arguments;
        PyMethodDescrObject * s9_method;
        PyMethodDef * s10_meth;
        PyObject * s11_self;
        int s12_nargs;
        PyObject * s13_args_o_temp[ 11 ];
        PyObject * * s14_args_o;
        _PyStackRef s15_tmp;
        int s16__i;
        PyCFunctionFast s17_cfunc;
        PyObject * s18_res_o;
        _PyStackRef s19_tmp;
        int s20__i;
        int s21_err;
    } op_CALL_METHOD_DESCRIPTOR_FAST;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        _PyStackRef * s8_arguments;
        PyMethodDescrObject * s9_method;
        PyMethodDef * s10_meth;
        PyTypeObject * s11_d_type;
        PyObject * s12_self;
        int s13_nargs;
        PyObject * s14_args_o_temp[ 11 ];
        PyObject * * s15_args_o;
        _PyStackRef s16_tmp;
        int s17__i;
        PyCFunctionFastWithKeywords s18_cfunc;
        PyObject * s19_res_o;
        _PyStackRef s20_tmp;
        int s21__i;
        int s22_err;
    } op_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        PyMethodDescrObject * s8_method;
        PyMethodDef * s9_meth;
        _PyStackRef s10_self_stackref;
        PyObject * s11_self;
        PyCFunction s12_cfunc;
        PyObject * s13_res_o;
        int s14_err;
    } op_CALL_METHOD_DESCRIPTOR_NOARGS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        int s7_total_args;
        _PyStackRef * s8_arguments;
        PyMethodDescrObject * s9_method;
        PyMethodDef * s10_meth;
        _PyStackRef s11_arg_stackref;
        _PyStackRef s12_self_stackref;
        PyCFunction s13_cfunc;
        PyObject * s14_res_o;
        _PyStackRef s15_tmp;
        int s16__i;
        int s17_err;
    } op_CALL_METHOD_DESCRIPTOR_O;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        PyObject * s7_callable_o;
        int s8_total_args;
        _PyStackRef * s9_arguments;
        PyObject * s10_args_o_temp[ 11 ];
        PyObject * * s11_args_o;
        _PyStackRef s12_tmp;
        int s13__i;
        PyObject * s14_res_o;
        _PyStackRef s15_tmp;
        int s16__i;
        int s17_err;
    } op_CALL_NON_PY_GENERAL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyInterpreterFrame * s5_new_frame;
        uint32_t s6_func_version;
        PyObject * s7_callable_o;
        PyFunctionObject * s8_func;
        PyObject * s9_callable_o;
        PyFunctionObject * s10_func;
        PyCodeObject * s11_code;
        PyObject * s12_callable_o;
        PyFunctionObject * s13_func;
        PyCodeObject * s14_code;
        int s15_has_self;
        _PyStackRef * s16_first_non_self_local;
        int s17_i;
        _PyInterpreterFrame * s18_temp;
    } op_CALL_PY_EXACT_ARGS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyInterpreterFrame * s5_new_frame;
        uint32_t s6_func_version;
        PyObject * s7_callable_o;
        PyFunctionObject * s8_func;
        PyObject * s9_callable_o;
        int s10_total_args;
        int s11_code_flags;
        PyObject * s12_locals;
        _PyInterpreterFrame * s13_temp;
        _PyInterpreterFrame * s14_temp;
    } op_CALL_PY_GENERAL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_null;
        _PyStackRef s3_callable;
        _PyStackRef s4_arg;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        PyObject * s7_arg_o;
        PyObject * s8_res_o;
        int s9_err;
    } op_CALL_STR_1;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_null;
        _PyStackRef s3_callable;
        _PyStackRef s4_arg;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        PyObject * s7_arg_o;
        PyObject * s8_res_o;
        int s9_err;
    } op_CALL_TUPLE_1;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_null;
        _PyStackRef s3_callable;
        _PyStackRef s4_arg;
        _PyStackRef s5_res;
        PyObject * s6_callable_o;
        PyObject * s7_arg_o;
    } op_CALL_TYPE_1;
    struct {
        unsigned char empty;
        _PyStackRef s1_exc_value_st;
        _PyStackRef s2_match_type_st;
        _PyStackRef s3_rest;
        _PyStackRef s4_match;
        PyObject * s5_exc_value;
        PyObject * s6_match_type;
        int s7_err;
        _PyStackRef s8_tmp;
        PyObject * s9_match_o;
        PyObject * s10_rest_o;
        int s11_res;
        _PyStackRef s12_tmp;
    } op_CHECK_EG_MATCH;
    struct {
        unsigned char empty;
        _PyStackRef s1_left;
        _PyStackRef s2_right;
        _PyStackRef s3_b;
        PyObject * s4_left_o;
        PyObject * s5_right_o;
        int s6_err;
        int s7_res;
    } op_CHECK_EXC_MATCH;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_sub_iter;
        _PyStackRef s3_last_sent_val;
        _PyStackRef s4_exc_value_st;
        _PyStackRef s5_none;
        _PyStackRef s6_value;
        PyObject * s7_exc_value;
        int s8_matches;
        _PyStackRef s9_tmp;
    } op_CLEANUP_THROW;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_left;
        _PyStackRef s3_right;
        _PyStackRef s4_res;
        uint16_t s5_counter;
        PyObject * s6_left_o;
        PyObject * s7_right_o;
        PyObject * s8_res_o;
        _PyStackRef s9_tmp;
        int s10_res_bool;
    } op_COMPARE_OP;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        double s10_dleft;
        double s11_dright;
        int s12_sign_ish;
    } op_COMPARE_OP_FLOAT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_res;
        PyObject * s6_value_o;
        PyObject * s7_left_o;
        PyObject * s8_left_o;
        PyObject * s9_right_o;
        Py_ssize_t s10_ileft;
        Py_ssize_t s11_iright;
        int s12_sign_ish;
    } op_COMPARE_OP_INT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_nos;
        _PyStackRef s4_left;
        _PyStackRef s5_right;
        _PyStackRef s6_res;
        PyObject * s7_value_o;
        PyObject * s8_o;
        PyObject * s9_left_o;
        PyObject * s10_right_o;
        int s11_eq;
    } op_COMPARE_OP_STR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_right;
        _PyStackRef s3_left;
        _PyStackRef s4_b;
        uint16_t s5_counter;
        PyObject * s6_left_o;
        PyObject * s7_right_o;
        int s8_res;
        _PyStackRef s9_tmp;
    } op_CONTAINS_OP;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_tos;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_b;
        PyObject * s6_o;
        PyObject * s7_left_o;
        PyObject * s8_right_o;
        int s9_res;
        _PyStackRef s10_tmp;
    } op_CONTAINS_OP_DICT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_tos;
        _PyStackRef s3_left;
        _PyStackRef s4_right;
        _PyStackRef s5_b;
        PyObject * s6_o;
        PyObject * s7_left_o;
        PyObject * s8_right_o;
        int s9_res;
        _PyStackRef s10_tmp;
    } op_CONTAINS_OP_SET;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_result;
        PyObject * s3_result_o;
    } op_CONVERT_VALUE;
    struct {
        unsigned char empty;
        _PyStackRef s1_bottom;
        _PyStackRef s2_top;
    } op_COPY;
    struct {
        unsigned char empty;
        PyCodeObject * s1_co;
        PyFunctionObject * s2_func;
        PyObject * s3_closure;
        int s4_offset;
        int s5_i;
        PyObject * s6_o;
    } op_COPY_FREE_VARS;
    struct {
        unsigned char empty;
        _PyStackRef s1_owner;
        PyObject * s2_name;
        int s3_err;
    } op_DELETE_ATTR;
    struct {
        unsigned char empty;
        PyObject * s1_cell;
        PyObject * s2_oldobj;
    } op_DELETE_DEREF;
    struct {
        unsigned char empty;
        _PyStackRef s1_v;
        _PyStackRef s2_tmp;
    } op_DELETE_FAST;
    struct {
        unsigned char empty;
        PyObject * s1_name;
        int s2_err;
    } op_DELETE_GLOBAL;
    struct {
        unsigned char empty;
        PyObject * s1_name;
        PyObject * s2_ns;
        int s3_err;
    } op_DELETE_NAME;
    struct {
        unsigned char empty;
        _PyStackRef s1_container;
        _PyStackRef s2_sub;
        int s3_err;
        _PyStackRef s4_tmp;
    } op_DELETE_SUBSCR;
    struct {
        unsigned char empty;
        _PyStackRef s1_callable;
        _PyStackRef s2_dict;
        _PyStackRef s3_update;
        PyObject * s4_callable_o;
        PyObject * s5_dict_o;
        PyObject * s6_update_o;
        int s7_err;
    } op_DICT_MERGE;
    struct {
        unsigned char empty;
        _PyStackRef s1_dict;
        _PyStackRef s2_update;
        PyObject * s3_dict_o;
        PyObject * s4_update_o;
        int s5_err;
        int s6_matches;
    } op_DICT_UPDATE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_awaitable_st;
        _PyStackRef s3_exc_st;
        PyObject * s4_exc;
        int s5_matches;
        _PyStackRef s6_tmp;
    } op_END_ASYNC_FOR;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
    } op_END_FOR;
    struct {
        unsigned char empty;
        _PyStackRef s1_receiver;
        _PyStackRef s2_value;
        _PyStackRef s3_val;
    } op_END_SEND;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
#if (defined(_Py_TIER2))
        PyCodeObject * s2_code;
#endif
#if (defined(_Py_TIER2))
        _PyExecutorObject * s3_executor;
#endif
    } op_ENTER_EXECUTOR;
    struct {
        unsigned char empty;
        _PyStackRef s1_should_be_none;
    } op_EXIT_INIT_CHECK;
    struct {
        unsigned char empty;
    } op_EXTENDED_ARG;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_res;
        PyObject * s3_value_o;
        PyObject * s4_res_o;
    } op_FORMAT_SIMPLE;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_fmt_spec;
        _PyStackRef s3_res;
        PyObject * s4_res_o;
        _PyStackRef s5_tmp;
    } op_FORMAT_WITH_SPEC;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_iter;
        _PyStackRef s3_next;
        uint16_t s4_counter;
        PyObject * s5_iter_o;
        PyObject * s6_next_o;
        int s7_matches;
    } op_FOR_ITER;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_iter;
        _PyInterpreterFrame * s3_gen_frame;
        _PyInterpreterFrame * s4_new_frame;
        PyGenObject * s5_gen;
        _PyInterpreterFrame * s6_temp;
    } op_FOR_ITER_GEN;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_iter;
        _PyStackRef s3_next;
        PyObject * s4_iter_o;
        PyObject * s5_iter_o;
        _PyListIterObject * s6_it;
        PyListObject * s7_seq;
        PyObject * s8_iter_o;
        _PyListIterObject * s9_it;
        PyListObject * s10_seq;
    } op_FOR_ITER_LIST;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_iter;
        _PyStackRef s3_next;
        _PyRangeIterObject * s4_r;
        _PyRangeIterObject * s5_r;
        _PyRangeIterObject * s6_r;
        long s7_value;
        PyObject * s8_res;
    } op_FOR_ITER_RANGE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_iter;
        _PyStackRef s3_next;
        PyObject * s4_iter_o;
        PyObject * s5_iter_o;
        _PyTupleIterObject * s6_it;
        PyTupleObject * s7_seq;
        PyObject * s8_iter_o;
        _PyTupleIterObject * s9_it;
        PyTupleObject * s10_seq;
    } op_FOR_ITER_TUPLE;
    struct {
        unsigned char empty;
        _PyStackRef s1_obj;
        _PyStackRef s2_iter;
        unaryfunc s3_getter;
        PyObject * s4_obj_o;
        PyObject * s5_iter_o;
        PyTypeObject * s6_type;
    } op_GET_AITER;
    struct {
        unsigned char empty;
        _PyStackRef s1_aiter;
        _PyStackRef s2_awaitable;
        PyObject * s3_awaitable_o;
    } op_GET_ANEXT;
    struct {
        unsigned char empty;
        _PyStackRef s1_iterable;
        _PyStackRef s2_iter;
        PyObject * s3_iter_o;
    } op_GET_AWAITABLE;
    struct {
        unsigned char empty;
        _PyStackRef s1_iterable;
        _PyStackRef s2_iter;
        PyObject * s3_iter_o;
    } op_GET_ITER;
    struct {
        unsigned char empty;
        _PyStackRef s1_obj;
        _PyStackRef s2_len;
        Py_ssize_t s3_len_i;
        PyObject * s4_len_o;
    } op_GET_LEN;
    struct {
        unsigned char empty;
        _PyStackRef s1_iterable;
        _PyStackRef s2_iter;
        PyObject * s3_iterable_o;
        PyObject * s4_iter_o;
        _PyStackRef s5_tmp;
    } op_GET_YIELD_FROM_ITER;
    struct {
        unsigned char empty;
        _PyStackRef s1_from;
        _PyStackRef s2_res;
        PyObject * s3_name;
        PyObject * s4_res_o;
    } op_IMPORT_FROM;
    struct {
        unsigned char empty;
        _PyStackRef s1_level;
        _PyStackRef s2_fromlist;
        _PyStackRef s3_res;
        PyObject * s4_name;
        PyObject * s5_res_o;
        _PyStackRef s6_tmp;
    } op_IMPORT_NAME;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef s4_func;
        _PyStackRef s5_maybe_self;
        _PyStackRef * s6_args;
        _PyStackRef s7_res;
        PyObject * s8_callable_o;
        PyObject * s9_self;
        PyObject * s10_method;
        _PyStackRef s11_temp;
        int s12_is_meth;
        PyObject * s13_function;
        PyObject * s14_arg0;
        int s15_err;
        PyObject * s16_callable_o;
        int s17_total_args;
        _PyStackRef * s18_arguments;
        int s19_code_flags;
        PyObject * s20_locals;
        _PyInterpreterFrame * s21_new_frame;
        PyObject * s22_args_o_temp[ 11 ];
        PyObject * * s23_args_o;
        _PyStackRef s24_tmp;
        int s25__i;
        PyObject * s26_res_o;
        PyObject * s27_arg;
        int s28_err;
        _PyStackRef s29_tmp;
        int s30__i;
        int s31_err;
    } op_INSTRUMENTED_CALL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_func;
        _PyStackRef s3_callargs;
        _PyStackRef s4_func_st;
        _PyStackRef s5_null;
        _PyStackRef s6_callargs_st;
        _PyStackRef s7_kwargs_st;
        _PyStackRef s8_result;
        PyObject * s9_callargs_o;
        int s10_err;
        PyObject * s11_tuple_o;
        _PyStackRef s12_temp;
        PyObject * s13_func;
        PyObject * s14_result_o;
        PyObject * s15_callargs;
        PyObject * s16_kwargs;
        PyObject * s17_arg;
        int s18_err;
        int s19_err;
        PyObject * s20_callargs;
        PyObject * s21_kwargs;
        Py_ssize_t s22_nargs;
        int s23_code_flags;
        PyObject * s24_locals;
        _PyInterpreterFrame * s25_new_frame;
        PyObject * s26_callargs;
        PyObject * s27_kwargs;
        int s28_err;
    } op_INSTRUMENTED_CALL_FUNCTION_EX;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_callable;
        _PyStackRef s3_self_or_null;
        _PyStackRef * s4_args;
        _PyStackRef s5_kwnames;
        _PyStackRef s6_res;
        PyObject * s7_callable_o;
        PyObject * s8_self;
        PyObject * s9_method;
        _PyStackRef s10_temp;
        int s11_is_meth;
        PyObject * s12_arg;
        PyObject * s13_function;
        int s14_err;
        PyObject * s15_callable_o;
        PyObject * s16_kwnames_o;
        int s17_total_args;
        _PyStackRef * s18_arguments;
        int s19_positional_args;
        int s20_code_flags;
        PyObject * s21_locals;
        _PyInterpreterFrame * s22_new_frame;
        PyObject * s23_args_o_temp[ 11 ];
        PyObject * * s24_args_o;
        _PyStackRef s25_tmp;
        int s26__i;
        PyObject * s27_res_o;
        PyObject * s28_arg;
        int s29_err;
        _PyStackRef s30_tmp;
        int s31__i;
    } op_INSTRUMENTED_CALL_KW;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_awaitable_st;
        _PyStackRef s3_exc_st;
        PyObject * s4_exc;
        int s5_matches;
        _PyStackRef s6_tmp;
    } op_INSTRUMENTED_END_ASYNC_FOR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_receiver;
        _PyStackRef s3_value;
        int s4_err;
    } op_INSTRUMENTED_END_FOR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_receiver;
        _PyStackRef s3_value;
        _PyStackRef s4_val;
        PyObject * s5_receiver_o;
        int s6_err;
    } op_INSTRUMENTED_END_SEND;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_iter;
        _PyStackRef s3_next;
        PyObject * s4_iter_o;
        PyObject * s5_next_o;
        int s6_matches;
    } op_INSTRUMENTED_FOR_ITER;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        int s2_next_opcode;
    } op_INSTRUMENTED_INSTRUCTION;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        int s2_err;
    } op_INSTRUMENTED_JUMP_BACKWARD;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
    } op_INSTRUMENTED_JUMP_FORWARD;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_prev_instr;
        _Py_CODEUNIT * s2_this_instr;
        int s3_original_opcode;
        PyCodeObject * s4_code;
        int s5_index;
        _PyBinaryOpCache * s6_cache;
    } op_INSTRUMENTED_LINE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_global_super_st;
        _PyStackRef s3_class_st;
        _PyStackRef s4_self_st;
        _PyStackRef s5_attr;
        _PyStackRef * s6_null;
        PyObject * s7_global_super;
        PyObject * s8_class;
        PyObject * s9_self;
        PyObject * s10_arg;
        int s11_err;
        _PyStackRef s12_tmp;
        PyObject * s13_stack[ ];
        PyObject * s14_super;
        PyObject * s15_arg;
        int s16_err;
        _PyStackRef s17_tmp;
        PyObject * s18_name;
        PyObject * s19_attr_o;
    } op_INSTRUMENTED_LOAD_SUPER_ATTR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_prev_instr;
        _Py_CODEUNIT * s2_this_instr;
    } op_INSTRUMENTED_NOT_TAKEN;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_prev_instr;
        _Py_CODEUNIT * s2_this_instr;
        _PyStackRef s3_iter;
    } op_INSTRUMENTED_POP_ITER;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_cond;
        int s3_jump;
    } op_INSTRUMENTED_POP_JUMP_IF_FALSE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        int s3_jump;
    } op_INSTRUMENTED_POP_JUMP_IF_NONE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        int s3_jump;
    } op_INSTRUMENTED_POP_JUMP_IF_NOT_NONE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_cond;
        int s3_jump;
    } op_INSTRUMENTED_POP_JUMP_IF_TRUE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        int s2_check_instrumentation;
        uintptr_t s3_global_version;
        uintptr_t s4_code_version;
        int s5_err;
        int s6_err;
        int s7_err;
    } op_INSTRUMENTED_RESUME;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_val;
        _PyStackRef s3_retval;
        _PyStackRef s4_res;
        int s5_err;
        _PyStackRef s6_temp;
        _PyInterpreterFrame * s7_dying;
    } op_INSTRUMENTED_RETURN_VALUE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_val;
        _PyStackRef s3_retval;
        _PyStackRef s4_value;
        int s5_err;
        PyGenObject * s6_gen;
        _PyStackRef s7_temp;
        _PyInterpreterFrame * s8_gen_frame;
    } op_INSTRUMENTED_YIELD_VALUE;
    struct {
        unsigned char empty;
        _PyStackRef s1_retval;
        PyObject * s2_result;
#if (defined(_Py_TIER2))
        _PyStackRef s3_executor;
#endif
    } op_INTERPRETER_EXIT;
    struct {
        unsigned char empty;
        _PyStackRef s1_left;
        _PyStackRef s2_right;
        _PyStackRef s3_b;
        int s4_res;
        _PyStackRef s5_tmp;
    } op_IS_OP;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        int s2_err;
    } op_JUMP_BACKWARD;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        int s2_err;
#if (defined(_Py_TIER2))
        _Py_BackoffCounter s3_counter;
#endif
#if (defined(_Py_TIER2))
        _Py_CODEUNIT * s4_start;
#endif
#if (defined(_Py_TIER2))
        _PyExecutorObject * s5_executor;
#endif
#if (defined(_Py_TIER2))
        int s6_optimized;
#endif
    } op_JUMP_BACKWARD_JIT;
    struct {
        unsigned char empty;
    } op_JUMP_BACKWARD_NO_INTERRUPT;
    struct {
        unsigned char empty;
        int s1_err;
    } op_JUMP_BACKWARD_NO_JIT;
    struct {
        unsigned char empty;
    } op_JUMP_FORWARD;
    struct {
        unsigned char empty;
        _PyStackRef s1_list;
        _PyStackRef s2_v;
        int s3_err;
    } op_LIST_APPEND;
    struct {
        unsigned char empty;
        _PyStackRef s1_list_st;
        _PyStackRef s2_iterable_st;
        PyObject * s3_list;
        PyObject * s4_iterable;
        PyObject * s5_none_val;
        int s6_matches;
    } op_LIST_EXTEND;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef * s4_self_or_null;
        uint16_t s5_counter;
#if (ENABLE_SPECIALIZATION_FT)
        PyObject * s6_name;
#endif
        PyObject * s7_name;
        PyObject * s8_attr_o;
    } op_LOAD_ATTR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef * s4_null;
        uint32_t s5_type_version;
        PyObject * s6_owner_o;
        PyObject * s7_descr;
        _PyStackRef s8_tmp;
    } op_LOAD_ATTR_CLASS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef * s4_null;
        uint32_t s5_type_version;
        PyObject * s6_owner_o;
        uint32_t s7_type_version;
        PyTypeObject * s8_tp;
        PyObject * s9_descr;
        _PyStackRef s10_tmp;
    } op_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        uint32_t s3_type_version;
        uint32_t s4_func_version;
        PyObject * s5_getattribute;
        PyObject * s6_owner_o;
        PyTypeObject * s7_cls;
        PyFunctionObject * s8_f;
        PyCodeObject * s9_code;
        PyObject * s10_name;
        _PyInterpreterFrame * s11_new_frame;
    } op_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef * s4_null;
        uint32_t s5_type_version;
        PyTypeObject * s6_tp;
        PyObject * s7_owner_o;
        uint16_t s8_offset;
        PyObject * s9_owner_o;
        PyObject * * s10_value_ptr;
        PyObject * s11_attr_o;
    } op_LOAD_ATTR_INSTANCE_VALUE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef s4_self;
        uint32_t s5_type_version;
        PyTypeObject * s6_tp;
        uint16_t s7_dictoffset;
        char * s8_ptr;
        PyObject * s9_dict;
        PyObject * s10_descr;
    } op_LOAD_ATTR_METHOD_LAZY_DICT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef s4_self;
        uint32_t s5_type_version;
        PyTypeObject * s6_tp;
        PyObject * s7_descr;
    } op_LOAD_ATTR_METHOD_NO_DICT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef s4_self;
        uint32_t s5_type_version;
        PyTypeObject * s6_tp;
        PyObject * s7_owner_o;
        PyDictValues * s8_ivs;
        uint32_t s9_keys_version;
        PyTypeObject * s10_owner_cls;
        PyHeapTypeObject * s11_owner_heap_type;
        PyDictKeysObject * s12_keys;
        PyObject * s13_descr;
    } op_LOAD_ATTR_METHOD_WITH_VALUES;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef * s4_null;
        uint32_t s5_dict_version;
        uint16_t s6_index;
        PyObject * s7_owner_o;
        PyDictObject * s8_dict;
        PyDictKeysObject * s9_keys;
        PyDictUnicodeEntry * s10_ep;
        PyObject * s11_attr_o;
    } op_LOAD_ATTR_MODULE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        uint32_t s4_type_version;
        PyTypeObject * s5_tp;
        PyObject * s6_descr;
    } op_LOAD_ATTR_NONDESCRIPTOR_NO_DICT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        uint32_t s4_type_version;
        PyTypeObject * s5_tp;
        PyObject * s6_owner_o;
        PyDictValues * s7_ivs;
        uint32_t s8_keys_version;
        PyTypeObject * s9_owner_cls;
        PyHeapTypeObject * s10_owner_heap_type;
        PyDictKeysObject * s11_keys;
        PyObject * s12_descr;
    } op_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyInterpreterFrame * s3_new_frame;
        uint32_t s4_type_version;
        PyTypeObject * s5_tp;
        PyObject * s6_fget;
        PyFunctionObject * s7_f;
        PyCodeObject * s8_code;
        _PyInterpreterFrame * s9_temp;
    } op_LOAD_ATTR_PROPERTY;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef * s4_null;
        uint32_t s5_type_version;
        PyTypeObject * s6_tp;
        uint16_t s7_index;
        PyObject * s8_owner_o;
        PyObject * * s9_addr;
        PyObject * s10_attr_o;
        _PyStackRef s11_tmp;
    } op_LOAD_ATTR_SLOT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_attr;
        _PyStackRef * s4_null;
        uint32_t s5_type_version;
        PyTypeObject * s6_tp;
        uint16_t s7_hint;
        PyObject * s8_owner_o;
        PyDictObject * s9_dict;
        PyDictKeysObject * s10_dk;
        PyObject * s11_attr_o;
        PyObject * s12_name;
        PyDictUnicodeEntry * s13_ep;
    } op_LOAD_ATTR_WITH_HINT;
    struct {
        unsigned char empty;
        _PyStackRef s1_bc;
        PyObject * s2_bc_o;
        int s3_err;
    } op_LOAD_BUILD_CLASS;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
    } op_LOAD_COMMON_CONSTANT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        PyObject * s3_obj;
    } op_LOAD_CONST;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        PyObject * s2_obj;
    } op_LOAD_CONST_IMMORTAL;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        PyObject * s2_obj;
    } op_LOAD_CONST_MORTAL;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        PyCellObject * s2_cell;
    } op_LOAD_DEREF;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
    } op_LOAD_FAST;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
    } op_LOAD_FAST_AND_CLEAR;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
    } op_LOAD_FAST_BORROW;
    struct {
        unsigned char empty;
        _PyStackRef s1_value1;
        _PyStackRef s2_value2;
        uint32_t s3_oparg1;
        uint32_t s4_oparg2;
    } op_LOAD_FAST_BORROW_LOAD_FAST_BORROW;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_value_s;
    } op_LOAD_FAST_CHECK;
    struct {
        unsigned char empty;
        _PyStackRef s1_value1;
        _PyStackRef s2_value2;
        uint32_t s3_oparg1;
        uint32_t s4_oparg2;
    } op_LOAD_FAST_LOAD_FAST;
    struct {
        unsigned char empty;
        _PyStackRef s1_class_dict_st;
        _PyStackRef s2_value;
        PyObject * s3_value_o;
        PyObject * s4_name;
        PyObject * s5_class_dict;
        int s6_err;
        PyCellObject * s7_cell;
    } op_LOAD_FROM_DICT_OR_DEREF;
    struct {
        unsigned char empty;
        _PyStackRef s1_mod_or_class_dict;
        _PyStackRef s2_v;
        PyObject * s3_name;
        PyObject * s4_v_o;
        int s5_err;
        int s6_err;
        int s7_err;
    } op_LOAD_FROM_DICT_OR_GLOBALS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef * s2_res;
        _PyStackRef * s3_null;
        uint16_t s4_counter;
#if (ENABLE_SPECIALIZATION_FT)
        PyObject * s5_name;
#endif
        PyObject * s6_name;
    } op_LOAD_GLOBAL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_res;
        _PyStackRef * s3_null;
        uint16_t s4_version;
        PyDictObject * s5_dict;
        PyDictKeysObject * s6_keys;
        uint16_t s7_version;
        uint16_t s8_index;
        PyDictObject * s9_dict;
        PyDictKeysObject * s10_keys;
        PyDictUnicodeEntry * s11_entries;
        PyObject * s12_res_o;
    } op_LOAD_GLOBAL_BUILTIN;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_res;
        _PyStackRef * s3_null;
        uint16_t s4_version;
        uint16_t s5_index;
        PyDictObject * s6_dict;
        PyDictKeysObject * s7_keys;
        PyDictUnicodeEntry * s8_entries;
        PyObject * s9_res_o;
    } op_LOAD_GLOBAL_MODULE;
    struct {
        unsigned char empty;
        _PyStackRef s1_locals;
        PyObject * s2_l;
    } op_LOAD_LOCALS;
    struct {
        unsigned char empty;
        _PyStackRef s1_v;
        PyObject * s2_name;
        PyObject * s3_v_o;
    } op_LOAD_NAME;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        PyObject * s2_obj;
    } op_LOAD_SMALL_INT;
    struct {
        unsigned char empty;
        _PyStackRef s1_self;
        _PyStackRef * s2_method_and_self;
        PyObject * s3_name;
        int s4_err;
        PyObject * s5_owner;
        const char * s6_errfmt;
    } op_LOAD_SPECIAL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_global_super_st;
        _PyStackRef s3_class_st;
        _PyStackRef s4_self_st;
        _PyStackRef s5_attr;
        _PyStackRef * s6_null;
        uint16_t s7_counter;
#if (ENABLE_SPECIALIZATION_FT)
        int s8_load_method;
#endif
        PyObject * s9_global_super;
        PyObject * s10_class;
        PyObject * s11_self;
        PyObject * s12_arg;
        int s13_err;
        _PyStackRef s14_tmp;
        PyObject * s15_stack[ ];
        PyObject * s16_super;
        PyObject * s17_arg;
        int s18_err;
        _PyStackRef s19_tmp;
        PyObject * s20_name;
        PyObject * s21_attr_o;
    } op_LOAD_SUPER_ATTR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_global_super_st;
        _PyStackRef s3_class_st;
        _PyStackRef s4_self_st;
        _PyStackRef s5_attr_st;
        PyObject * s6_global_super;
        PyObject * s7_class;
        PyObject * s8_self;
        PyObject * s9_name;
        PyObject * s10_attr;
        _PyStackRef s11_tmp;
    } op_LOAD_SUPER_ATTR_ATTR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_global_super_st;
        _PyStackRef s3_class_st;
        _PyStackRef s4_self_st;
        _PyStackRef s5_attr;
        _PyStackRef s6_self_or_null;
        PyObject * s7_global_super;
        PyObject * s8_class;
        PyObject * s9_self;
        PyObject * s10_name;
        PyTypeObject * s11_cls;
        int s12_method_found;
        PyObject * s13_attr_o;
        _PyStackRef s14_tmp;
    } op_LOAD_SUPER_ATTR_METHOD;
    struct {
        unsigned char empty;
        PyObject * s1_initial;
        PyObject * s2_cell;
        _PyStackRef s3_tmp;
    } op_MAKE_CELL;
    struct {
        unsigned char empty;
        _PyStackRef s1_codeobj_st;
        _PyStackRef s2_func;
        PyObject * s3_codeobj;
        PyFunctionObject * s4_func_obj;
    } op_MAKE_FUNCTION;
    struct {
        unsigned char empty;
        _PyStackRef s1_dict_st;
        _PyStackRef s2_key;
        _PyStackRef s3_value;
        PyObject * s4_dict;
        int s5_err;
    } op_MAP_ADD;
    struct {
        unsigned char empty;
        _PyStackRef s1_subject;
        _PyStackRef s2_type;
        _PyStackRef s3_names;
        _PyStackRef s4_attrs;
        PyObject * s5_attrs_o;
        _PyStackRef s6_tmp;
    } op_MATCH_CLASS;
    struct {
        unsigned char empty;
        _PyStackRef s1_subject;
        _PyStackRef s2_keys;
        _PyStackRef s3_values_or_none;
        PyObject * s4_values_or_none_o;
    } op_MATCH_KEYS;
    struct {
        unsigned char empty;
        _PyStackRef s1_subject;
        _PyStackRef s2_res;
        int s3_match;
    } op_MATCH_MAPPING;
    struct {
        unsigned char empty;
        _PyStackRef s1_subject;
        _PyStackRef s2_res;
        int s3_match;
    } op_MATCH_SEQUENCE;
    struct {
        unsigned char empty;
    } op_NOP;
    struct {
        unsigned char empty;
    } op_NOT_TAKEN;
    struct {
        unsigned char empty;
        _PyStackRef s1_exc_value;
        _PyErr_StackItem * s2_exc_info;
    } op_POP_EXCEPT;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
    } op_POP_ITER;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_cond;
        int s3_flag;
    } op_POP_JUMP_IF_FALSE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_b;
        _PyStackRef s4_cond;
        _PyStackRef s5_tmp;
        int s6_flag;
    } op_POP_JUMP_IF_NONE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_b;
        _PyStackRef s4_cond;
        _PyStackRef s5_tmp;
        int s6_flag;
    } op_POP_JUMP_IF_NOT_NONE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_cond;
        int s3_flag;
    } op_POP_JUMP_IF_TRUE;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
    } op_POP_TOP;
    struct {
        unsigned char empty;
        _PyStackRef s1_exc;
        _PyStackRef s2_prev_exc;
        _PyStackRef s3_new_exc;
        _PyErr_StackItem * s4_exc_info;
    } op_PUSH_EXC_INFO;
    struct {
        unsigned char empty;
        _PyStackRef s1_res;
    } op_PUSH_NULL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef * s2_args;
        PyObject * s3_cause;
        PyObject * s4_exc;
        int s5_err;
    } op_RAISE_VARARGS;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef * s2_values;
        _PyStackRef s3_exc_st;
        PyObject * s4_exc;
    } op_RERAISE;
    struct {
        unsigned char empty;
    } op_RESERVED;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        int s2_check_instrumentation;
        uintptr_t s3_global_version;
        uintptr_t s4_code_version;
        int s5_err;
        int s6_err;
    } op_RESUME;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        uintptr_t s2_eval_breaker;
        uintptr_t s3_version;
    } op_RESUME_CHECK;
    struct {
        unsigned char empty;
        _PyStackRef s1_res;
        PyFunctionObject * s2_func;
        PyGenObject * s3_gen;
        _PyInterpreterFrame * s4_gen_frame;
        _PyInterpreterFrame * s5_prev;
    } op_RETURN_GENERATOR;
    struct {
        unsigned char empty;
        _PyStackRef s1_retval;
        _PyStackRef s2_res;
        _PyStackRef s3_temp;
        _PyInterpreterFrame * s4_dying;
    } op_RETURN_VALUE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_receiver;
        _PyStackRef s3_v;
        _PyStackRef s4_retval;
        uint16_t s5_counter;
        PyObject * s6_receiver_o;
        PyObject * s7_retval_o;
        PyGenObject * s8_gen;
        _PyInterpreterFrame * s9_gen_frame;
        int s10_matches;
        int s11_err;
    } op_SEND;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_receiver;
        _PyStackRef s3_v;
        _PyInterpreterFrame * s4_gen_frame;
        _PyInterpreterFrame * s5_new_frame;
        PyGenObject * s6_gen;
        _PyInterpreterFrame * s7_temp;
    } op_SEND_GEN;
    struct {
        unsigned char empty;
        PyObject * s1_ann_dict;
        int s2_err;
    } op_SETUP_ANNOTATIONS;
    struct {
        unsigned char empty;
        _PyStackRef s1_set;
        _PyStackRef s2_v;
        int s3_err;
    } op_SET_ADD;
    struct {
        unsigned char empty;
        _PyStackRef s1_attr_st;
        _PyStackRef s2_func_in;
        _PyStackRef s3_func_out;
        PyObject * s4_func;
        PyObject * s5_attr;
        size_t s6_offset;
        PyObject * * s7_ptr;
        PyFunctionObject * s8_func_obj;
        PyObject * s9_fixed_qualname;
    } op_SET_FUNCTION_ATTRIBUTE;
    struct {
        unsigned char empty;
        _PyStackRef s1_set;
        _PyStackRef s2_iterable;
        int s3_err;
    } op_SET_UPDATE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_v;
        uint16_t s4_counter;
#if (ENABLE_SPECIALIZATION_FT)
        PyObject * s5_name;
#endif
        PyObject * s6_name;
        int s7_err;
        _PyStackRef s8_tmp;
    } op_STORE_ATTR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_value;
        uint32_t s4_type_version;
        PyObject * s5_owner_o;
        PyTypeObject * s6_tp;
        PyObject * s7_owner_o;
        uint16_t s8_offset;
        PyObject * s9_owner_o;
        PyObject * * s10_value_ptr;
        PyObject * s11_old_value;
        PyDictValues * s12_values;
        Py_ssize_t s13_index;
    } op_STORE_ATTR_INSTANCE_VALUE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_value;
        uint32_t s4_type_version;
        PyTypeObject * s5_tp;
        uint16_t s6_index;
        PyObject * s7_owner_o;
        char * s8_addr;
        PyObject * s9_old_value;
    } op_STORE_ATTR_SLOT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_value;
        uint32_t s4_type_version;
        PyTypeObject * s5_tp;
        uint16_t s6_hint;
        PyObject * s7_owner_o;
        PyDictObject * s8_dict;
        PyObject * s9_name;
        PyDictUnicodeEntry * s10_ep;
        PyObject * s11_old_value;
    } op_STORE_ATTR_WITH_HINT;
    struct {
        unsigned char empty;
        _PyStackRef s1_v;
        PyCellObject * s2_cell;
    } op_STORE_DEREF;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_tmp;
    } op_STORE_FAST;
    struct {
        unsigned char empty;
        _PyStackRef s1_value1;
        _PyStackRef s2_value2;
        uint32_t s3_oparg1;
        uint32_t s4_oparg2;
        _PyStackRef s5_tmp;
    } op_STORE_FAST_LOAD_FAST;
    struct {
        unsigned char empty;
        _PyStackRef s1_value2;
        _PyStackRef s2_value1;
        uint32_t s3_oparg1;
        uint32_t s4_oparg2;
        _PyStackRef s5_tmp;
    } op_STORE_FAST_STORE_FAST;
    struct {
        unsigned char empty;
        _PyStackRef s1_v;
        PyObject * s2_name;
        int s3_err;
    } op_STORE_GLOBAL;
    struct {
        unsigned char empty;
        _PyStackRef s1_v;
        PyObject * s2_name;
        PyObject * s3_ns;
        int s4_err;
    } op_STORE_NAME;
    struct {
        unsigned char empty;
        _PyStackRef s1_v;
        _PyStackRef s2_container;
        _PyStackRef s3_start;
        _PyStackRef s4_stop;
        PyObject * s5_slice;
        int s6_err;
        _PyStackRef s7_tmp;
    } op_STORE_SLICE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_container;
        _PyStackRef s3_sub;
        _PyStackRef s4_v;
        uint16_t s5_counter;
        int s6_err;
        _PyStackRef s7_tmp;
    } op_STORE_SUBSCR;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_nos;
        _PyStackRef s3_value;
        _PyStackRef s4_dict_st;
        _PyStackRef s5_sub;
        PyObject * s6_o;
        PyObject * s7_dict;
        int s8_err;
    } op_STORE_SUBSCR_DICT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_nos;
        _PyStackRef s4_list_st;
        _PyStackRef s5_sub_st;
        PyObject * s6_value_o;
        PyObject * s7_o;
        PyObject * s8_sub;
        PyObject * s9_list;
        Py_ssize_t s10_index;
        PyObject * s11_old_value;
    } op_STORE_SUBSCR_LIST_INT;
    struct {
        unsigned char empty;
        _PyStackRef s1_bottom;
        _PyStackRef s2_top;
        _PyStackRef s3_temp;
    } op_SWAP;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_res;
        uint16_t s4_counter;
        int s5_err;
    } op_TO_BOOL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_owner;
        _PyStackRef s3_value;
        _PyStackRef s4_res;
        uint32_t s5_type_version;
        PyTypeObject * s6_tp;
    } op_TO_BOOL_ALWAYS_TRUE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
    } op_TO_BOOL_BOOL;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_res;
        PyObject * s4_value_o;
    } op_TO_BOOL_INT;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_tos;
        _PyStackRef s3_value;
        _PyStackRef s4_res;
        PyObject * s5_o;
        PyObject * s6_value_o;
        _PyStackRef s7_tmp;
    } op_TO_BOOL_LIST;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_res;
    } op_TO_BOOL_NONE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_value;
        _PyStackRef s3_res;
        PyObject * s4_value_o;
        PyObject * s5_value_o;
    } op_TO_BOOL_STR;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_res;
        PyObject * s3_res_o;
    } op_UNARY_INVERT;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_res;
        PyObject * s3_res_o;
    } op_UNARY_NEGATIVE;
    struct {
        unsigned char empty;
        _PyStackRef s1_value;
        _PyStackRef s2_res;
    } op_UNARY_NOT;
    struct {
        unsigned char empty;
        _PyStackRef s1_seq;
        _PyStackRef * s2_top;
        PyObject * s3_seq_o;
        int s4_res;
    } op_UNPACK_EX;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_seq;
        _PyStackRef * s3_top;
        uint16_t s4_counter;
        PyObject * s5_seq_o;
        int s6_res;
    } op_UNPACK_SEQUENCE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_tos;
        _PyStackRef s3_seq;
        _PyStackRef * s4_values;
        PyObject * s5_o;
        PyObject * s6_seq_o;
        PyObject * * s7_items;
        int s8_i;
    } op_UNPACK_SEQUENCE_LIST;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_tos;
        _PyStackRef s3_seq;
        _PyStackRef * s4_values;
        PyObject * s5_o;
        PyObject * s6_seq_o;
        PyObject * * s7_items;
        int s8_i;
    } op_UNPACK_SEQUENCE_TUPLE;
    struct {
        unsigned char empty;
        _Py_CODEUNIT * s1_this_instr;
        _PyStackRef s2_tos;
        _PyStackRef s3_seq;
        _PyStackRef s4_val1;
        _PyStackRef s5_val0;
        PyObject * s6_o;
        PyObject * s7_seq_o;
    } op_UNPACK_SEQUENCE_TWO_TUPLE;
    struct {
        unsigned char empty;
        _PyStackRef s1_exit_func;
        _PyStackRef s2_exit_self;
        _PyStackRef s3_lasti;
        _PyStackRef s4_val;
        _PyStackRef s5_res;
        PyObject * s6_exc;
        PyObject * s7_tb;
        PyObject * s8_val_o;
        PyObject * s9_exit_func_o;
        PyObject * s10_original_tb;
        PyObject * s11_stack[ 5 ];
        int s12_has_self;
        PyObject * s13_res_o;
    } op_WITH_EXCEPT_START;
    struct {
        unsigned char empty;
        _PyStackRef s1_retval;
        _PyStackRef s2_value;
        PyGenObject * s3_gen;
        _PyStackRef s4_temp;
        _PyInterpreterFrame * s5_gen_frame;
    } op_YIELD_VALUE;
    struct {
        unsigned char empty;
    } pop_2_error;
    struct {
        unsigned char empty;
    } pop_1_error;
    struct {
        unsigned char empty;
        PyFrameObject * s1_f;
    } error;
    struct {
        unsigned char empty;
        int s1_offset;
        int s2_level;
        int s3_handler;
        int s4_lasti;
        int s5_handled;
        _PyStackRef * s6_stackbase;
        _PyStackRef s7_ref;
        _PyStackRef * s8_new_top;
        _PyStackRef s9_ref;
        int s10_frame_lasti;
        _PyStackRef s11_lasti;
        PyObject * s12_exc;
        int s13_err;
    } exception_unwind;
    struct {
        unsigned char empty;
        _PyInterpreterFrame * s1_dying;
#if (defined(_Py_TIER2))
        _PyStackRef s2_executor;
#endif
    } exit_unwind;
    struct {
        unsigned char empty;
        int s1_too_deep;
    } start_frame;
    struct {
        unsigned char empty;
    } uop__NOP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        int s1_err;
#endif
    } uop__CHECK_PERIODIC;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        int s1_err;
#endif
    } uop__CHECK_PERIODIC_IF_NOT_YIELD_FROM;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        uintptr_t s1_eval_breaker;
#endif
#if (defined(_Py_TIER2))
        uintptr_t s2_version;
#endif
    } uop__RESUME_CHECK;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value_s;
#endif
    } uop__LOAD_FAST_CHECK;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_0;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_2;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_3;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_4;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_5;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_6;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_7;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_0;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_2;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_3;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_4;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_5;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_6;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW_7;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_BORROW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_FAST_AND_CLEAR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_obj;
#endif
    } uop__LOAD_CONST_MORTAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_obj;
#endif
    } uop__LOAD_CONST_IMMORTAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_obj;
#endif
    } uop__LOAD_SMALL_INT_0;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_obj;
#endif
    } uop__LOAD_SMALL_INT_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_obj;
#endif
    } uop__LOAD_SMALL_INT_2;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_obj;
#endif
    } uop__LOAD_SMALL_INT_3;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_obj;
#endif
    } uop__LOAD_SMALL_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_0;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_2;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_3;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_4;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_5;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_6;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST_7;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__STORE_FAST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__POP_TOP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_res;
#endif
    } uop__PUSH_NULL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__END_FOR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_receiver;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_val;
#endif
    } uop__END_SEND;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_res_o;
#endif
    } uop__UNARY_NEGATIVE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
    } uop__UNARY_NOT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__TO_BOOL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__TO_BOOL_BOOL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_value_o;
#endif
    } uop__TO_BOOL_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_nos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_NOS_LIST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_tos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_TOS_LIST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_tos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_TOS_SLICE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_value_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_tmp;
#endif
    } uop__TO_BOOL_LIST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
    } uop__TO_BOOL_NONE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_nos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_NOS_UNICODE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_value_o;
#endif
    } uop__GUARD_TOS_UNICODE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_value_o;
#endif
    } uop__TO_BOOL_STR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
    } uop__REPLACE_WITH_TRUE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_res_o;
#endif
    } uop__UNARY_INVERT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_left;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_left_o;
#endif
    } uop__GUARD_NOS_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_value_o;
#endif
    } uop__GUARD_TOS_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
    } uop__BINARY_OP_MULTIPLY_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
    } uop__BINARY_OP_ADD_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
    } uop__BINARY_OP_SUBTRACT_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_left;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_left_o;
#endif
    } uop__GUARD_NOS_FLOAT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_value_o;
#endif
    } uop__GUARD_TOS_FLOAT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        double s6_dres;
#endif
    } uop__BINARY_OP_MULTIPLY_FLOAT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        double s6_dres;
#endif
    } uop__BINARY_OP_ADD_FLOAT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        double s6_dres;
#endif
    } uop__BINARY_OP_SUBTRACT_FLOAT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
    } uop__BINARY_OP_ADD_UNICODE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_left_o;
#endif
#if (defined(_Py_TIER2))
        int s4_next_oparg;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s5_target_local;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_temp;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_right_o;
#endif
    } uop__BINARY_OP_INPLACE_ADD_UNICODE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_descr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        _PyBinaryOpSpecializationDescr * s6_d;
#endif
#if (defined(_Py_TIER2))
        int s7_res;
#endif
    } uop__GUARD_BINARY_OP_EXTEND;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_descr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_right_o;
#endif
#if (defined(_Py_TIER2))
        _PyBinaryOpSpecializationDescr * s7_d;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s9_tmp;
#endif
    } uop__BINARY_OP_EXTEND;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_stop;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_start;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_container;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_slice;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
    } uop__BINARY_SLICE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_stop;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_start;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_container;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_v;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_slice;
#endif
#if (defined(_Py_TIER2))
        int s6_err;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__STORE_SLICE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_list_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_sub;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_list;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s6_index;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_tmp;
#endif
    } uop__BINARY_OP_SUBSCR_LIST_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_list_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_sub;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_list;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__BINARY_OP_SUBSCR_LIST_SLICE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_str_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_sub;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_str;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s6_index;
#endif
#if (defined(_Py_TIER2))
        Py_UCS4 s7_c;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_res_o;
#endif
    } uop__BINARY_OP_SUBSCR_STR_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_nos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_NOS_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_tos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_TOS_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tuple_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_sub;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_tuple;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s6_index;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_tmp;
#endif
    } uop__BINARY_OP_SUBSCR_TUPLE_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_nos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_NOS_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_tos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_TOS_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_dict_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_sub;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_dict;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
#if (defined(_Py_TIER2))
        int s7_rc;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_tmp;
#endif
    } uop__BINARY_OP_SUBSCR_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_container;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_getitem;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s3_tp;
#endif
#if (defined(_Py_TIER2))
        PyHeapTypeObject * s4_ht;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_getitem_o;
#endif
#if (defined(_Py_TIER2))
        uint32_t s6_cached_version;
#endif
#if (defined(_Py_TIER2))
        PyCodeObject * s7_code;
#endif
    } uop__BINARY_OP_SUBSCR_CHECK_FUNC;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_getitem;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_sub;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_container;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
    } uop__BINARY_OP_SUBSCR_INIT_CALL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_list;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__LIST_APPEND;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_set;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__SET_ADD;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_container;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_v;
#endif
#if (defined(_Py_TIER2))
        int s4_err;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_tmp;
#endif
    } uop__STORE_SUBSCR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_list_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_sub;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_list;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s6_index;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_old_value;
#endif
    } uop__STORE_SUBSCR_LIST_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_dict_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_dict;
#endif
#if (defined(_Py_TIER2))
        int s5_err;
#endif
    } uop__STORE_SUBSCR_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_sub;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_container;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_tmp;
#endif
    } uop__DELETE_SUBSCR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_res_o;
#endif
    } uop__CALL_INTRINSIC_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value1_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value2_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_value1;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_value2;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__CALL_INTRINSIC_2;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_retval;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_temp;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_dying;
#endif
    } uop__RETURN_VALUE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_obj;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_iter;
#endif
#if (defined(_Py_TIER2))
        unaryfunc s3_getter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_obj_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_iter_o;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s6_type;
#endif
    } uop__GET_AITER;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_aiter;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_awaitable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_awaitable_o;
#endif
    } uop__GET_ANEXT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iterable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_iter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_iter_o;
#endif
    } uop__GET_AWAITABLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_receiver;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s3_gen_frame;
#endif
#if (defined(_Py_TIER2))
        PyGenObject * s4_gen;
#endif
    } uop__SEND_GEN_FRAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_retval;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        PyGenObject * s3_gen;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_temp;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s5_gen_frame;
#endif
    } uop__YIELD_VALUE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_exc_value;
#endif
#if (defined(_Py_TIER2))
        _PyErr_StackItem * s2_exc_info;
#endif
    } uop__POP_EXCEPT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
    } uop__LOAD_COMMON_CONSTANT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_bc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_bc_o;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__LOAD_BUILD_CLASS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_ns;
#endif
#if (defined(_Py_TIER2))
        int s4_err;
#endif
    } uop__STORE_NAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_ns;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__DELETE_NAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_seq;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s2_top;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_seq_o;
#endif
#if (defined(_Py_TIER2))
        int s4_res;
#endif
    } uop__UNPACK_SEQUENCE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_seq;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_val1;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_val0;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_seq_o;
#endif
    } uop__UNPACK_SEQUENCE_TWO_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_seq;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s2_values;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_seq_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * * s4_items;
#endif
#if (defined(_Py_TIER2))
        int s5_i;
#endif
    } uop__UNPACK_SEQUENCE_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_seq;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s2_values;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_seq_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * * s4_items;
#endif
#if (defined(_Py_TIER2))
        int s5_i;
#endif
    } uop__UNPACK_SEQUENCE_LIST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_seq;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s2_top;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_seq_o;
#endif
#if (defined(_Py_TIER2))
        int s4_res;
#endif
    } uop__UNPACK_EX;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_v;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_name;
#endif
#if (defined(_Py_TIER2))
        int s4_err;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_tmp;
#endif
    } uop__STORE_ATTR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_name;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__DELETE_ATTR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_name;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__STORE_GLOBAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_name;
#endif
#if (defined(_Py_TIER2))
        int s2_err;
#endif
    } uop__DELETE_GLOBAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_locals;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_l;
#endif
    } uop__LOAD_LOCALS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_v_o;
#endif
    } uop__LOAD_NAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_name;
#endif
    } uop__LOAD_GLOBAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_null;
#endif
    } uop__PUSH_NULL_CONDITIONAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        uint16_t s1_version;
#endif
#if (defined(_Py_TIER2))
        PyDictObject * s2_dict;
#endif
#if (defined(_Py_TIER2))
        PyDictKeysObject * s3_keys;
#endif
    } uop__GUARD_GLOBALS_VERSION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_res;
#endif
#if (defined(_Py_TIER2))
        uint16_t s2_version;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_index;
#endif
#if (defined(_Py_TIER2))
        PyDictObject * s4_dict;
#endif
#if (defined(_Py_TIER2))
        PyDictKeysObject * s5_keys;
#endif
#if (defined(_Py_TIER2))
        PyDictUnicodeEntry * s6_entries;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_res_o;
#endif
    } uop__LOAD_GLOBAL_MODULE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_res;
#endif
#if (defined(_Py_TIER2))
        uint16_t s2_version;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_index;
#endif
#if (defined(_Py_TIER2))
        PyDictObject * s4_dict;
#endif
#if (defined(_Py_TIER2))
        PyDictKeysObject * s5_keys;
#endif
#if (defined(_Py_TIER2))
        PyDictUnicodeEntry * s6_entries;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_res_o;
#endif
    } uop__LOAD_GLOBAL_BUILTINS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tmp;
#endif
    } uop__DELETE_FAST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_initial;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_cell;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_tmp;
#endif
    } uop__MAKE_CELL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_cell;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_oldobj;
#endif
    } uop__DELETE_DEREF;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_class_dict_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_value_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_class_dict;
#endif
#if (defined(_Py_TIER2))
        int s6_err;
#endif
#if (defined(_Py_TIER2))
        PyCellObject * s7_cell;
#endif
    } uop__LOAD_FROM_DICT_OR_DEREF;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyCellObject * s2_cell;
#endif
    } uop__LOAD_DEREF;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_v;
#endif
#if (defined(_Py_TIER2))
        PyCellObject * s2_cell;
#endif
    } uop__STORE_DEREF;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyCodeObject * s1_co;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s2_func;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_closure;
#endif
#if (defined(_Py_TIER2))
        int s4_offset;
#endif
#if (defined(_Py_TIER2))
        int s5_i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_o;
#endif
    } uop__COPY_FREE_VARS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_pieces;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_str;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_pieces_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s4_pieces_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_tmp;
#endif
#if (defined(_Py_TIER2))
        int s6__i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_str_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_tmp;
#endif
#if (defined(_Py_TIER2))
        int s9__i;
#endif
    } uop__BUILD_STRING;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_format;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_str;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_interpolation;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_value_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_str_o;
#endif
#if (defined(_Py_TIER2))
        int s7_conversion;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_format_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_interpolation_o;
#endif
    } uop__BUILD_INTERPOLATION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_interpolations;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_strings;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_template;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_strings_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_interpolations_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_template_o;
#endif
    } uop__BUILD_TEMPLATE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_values;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_tup;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_tup_o;
#endif
    } uop__BUILD_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_values;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_list;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_list_o;
#endif
    } uop__BUILD_LIST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iterable_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_list_st;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_list;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_iterable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_none_val;
#endif
#if (defined(_Py_TIER2))
        int s6_matches;
#endif
    } uop__LIST_EXTEND;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iterable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_set;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
    } uop__SET_UPDATE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_values;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_set;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_set_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_tmp;
#endif
#if (defined(_Py_TIER2))
        int s5__i;
#endif
#if (defined(_Py_TIER2))
        int s6_err;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s7_i;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_value;
#endif
    } uop__BUILD_SET;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_values;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_map;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_values_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s4_values_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_tmp;
#endif
#if (defined(_Py_TIER2))
        int s6__i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_map_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_tmp;
#endif
#if (defined(_Py_TIER2))
        int s9__i;
#endif
    } uop__BUILD_MAP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_ann_dict;
#endif
#if (defined(_Py_TIER2))
        int s2_err;
#endif
    } uop__SETUP_ANNOTATIONS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_update;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_dict;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_dict_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_update_o;
#endif
#if (defined(_Py_TIER2))
        int s5_err;
#endif
#if (defined(_Py_TIER2))
        int s6_matches;
#endif
    } uop__DICT_UPDATE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_update;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_dict;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_dict_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_update_o;
#endif
#if (defined(_Py_TIER2))
        int s7_err;
#endif
    } uop__DICT_MERGE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_key;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_dict_st;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_dict;
#endif
#if (defined(_Py_TIER2))
        int s5_err;
#endif
    } uop__MAP_ADD;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_class_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_global_super_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_attr_st;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_global_super;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_class;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_attr;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s10_tmp;
#endif
    } uop__LOAD_SUPER_ATTR_ATTR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_class_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_global_super_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_attr;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_self_or_null;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_global_super;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_class;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_name;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s10_cls;
#endif
#if (defined(_Py_TIER2))
        int s11_method_found;
#endif
#if (defined(_Py_TIER2))
        PyObject * s12_attr_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s13_tmp;
#endif
    } uop__LOAD_SUPER_ATTR_METHOD;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s3_self_or_null;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_attr_o;
#endif
    } uop__LOAD_ATTR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        uint32_t s2_type_version;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s3_tp;
#endif
    } uop__GUARD_TYPE_VERSION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        uint32_t s2_type_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s4_tp;
#endif
    } uop__GUARD_TYPE_VERSION_AND_LOCK;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_owner_o;
#endif
    } uop__CHECK_MANAGED_OBJECT_HAS_VALUES;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_offset;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * * s5_value_ptr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_attr_o;
#endif
    } uop__LOAD_ATTR_INSTANCE_VALUE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        uint32_t s3_dict_version;
#endif
#if (defined(_Py_TIER2))
        uint16_t s4_index;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyDictObject * s6_dict;
#endif
#if (defined(_Py_TIER2))
        PyDictKeysObject * s7_keys;
#endif
#if (defined(_Py_TIER2))
        PyDictUnicodeEntry * s8_ep;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_attr_o;
#endif
    } uop__LOAD_ATTR_MODULE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_hint;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyDictObject * s5_dict;
#endif
#if (defined(_Py_TIER2))
        PyDictKeysObject * s6_dk;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_attr_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_name;
#endif
#if (defined(_Py_TIER2))
        PyDictUnicodeEntry * s9_ep;
#endif
    } uop__LOAD_ATTR_WITH_HINT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_index;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * * s5_addr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_attr_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__LOAD_ATTR_SLOT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        uint32_t s2_type_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_owner_o;
#endif
    } uop__CHECK_ATTR_CLASS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_descr;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_tmp;
#endif
    } uop__LOAD_ATTR_CLASS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s2_new_frame;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_fget;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s4_f;
#endif
#if (defined(_Py_TIER2))
        PyCodeObject * s5_code;
#endif
    } uop__LOAD_ATTR_PROPERTY_FRAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_owner_o;
#endif
    } uop__GUARD_DORV_NO_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_offset;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * * s5_value_ptr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_old_value;
#endif
#if (defined(_Py_TIER2))
        PyDictValues * s7_values;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s8_index;
#endif
    } uop__STORE_ATTR_INSTANCE_VALUE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_hint;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyDictObject * s5_dict;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_name;
#endif
#if (defined(_Py_TIER2))
        PyDictUnicodeEntry * s7_ep;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_old_value;
#endif
    } uop__STORE_ATTR_WITH_HINT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        uint16_t s3_index;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_owner_o;
#endif
#if (defined(_Py_TIER2))
        char * s5_addr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_old_value;
#endif
    } uop__STORE_ATTR_SLOT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
#if (defined(_Py_TIER2))
        int s8_res_bool;
#endif
    } uop__COMPARE_OP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        double s6_dleft;
#endif
#if (defined(_Py_TIER2))
        double s7_dright;
#endif
#if (defined(_Py_TIER2))
        int s8_sign_ish;
#endif
    } uop__COMPARE_OP_FLOAT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s6_ileft;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s7_iright;
#endif
#if (defined(_Py_TIER2))
        int s8_sign_ish;
#endif
    } uop__COMPARE_OP_INT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        int s6_eq;
#endif
    } uop__COMPARE_OP_STR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_b;
#endif
#if (defined(_Py_TIER2))
        int s4_res;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_tmp;
#endif
    } uop__IS_OP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_b;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        int s6_res;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__CONTAINS_OP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_tos;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_o;
#endif
    } uop__GUARD_TOS_ANY_SET;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_b;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        int s6_res;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__CONTAINS_OP_SET;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_b;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        int s6_res;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__CONTAINS_OP_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_match_type_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_exc_value_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_rest;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_match;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_exc_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_match_type;
#endif
#if (defined(_Py_TIER2))
        int s7_err;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_tmp;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_match_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s10_rest_o;
#endif
#if (defined(_Py_TIER2))
        int s11_res;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s12_tmp;
#endif
    } uop__CHECK_EG_MATCH;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_right;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_left;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_b;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_left_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_right_o;
#endif
#if (defined(_Py_TIER2))
        int s6_err;
#endif
#if (defined(_Py_TIER2))
        int s7_res;
#endif
    } uop__CHECK_EXC_MATCH;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_fromlist;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_level;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s6_tmp;
#endif
    } uop__IMPORT_NAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_from;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_name;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_res_o;
#endif
    } uop__IMPORT_FROM;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_b;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_tmp;
#endif
    } uop__IS_NONE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_obj;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_len;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s3_len_i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_len_o;
#endif
    } uop__GET_LEN;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_names;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_type;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_subject;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_attrs;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_attrs_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s6_tmp;
#endif
    } uop__MATCH_CLASS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_subject;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        int s3_match;
#endif
    } uop__MATCH_MAPPING;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_subject;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        int s3_match;
#endif
    } uop__MATCH_SEQUENCE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_keys;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_subject;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_values_or_none;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_values_or_none_o;
#endif
    } uop__MATCH_KEYS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iterable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_iter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_iter_o;
#endif
    } uop__GET_ITER;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iterable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_iter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_iterable_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_iter_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_tmp;
#endif
    } uop__GET_YIELD_FROM_ITER;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_next;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_iter_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_next_o;
#endif
#if (defined(_Py_TIER2))
        int s5_matches;
#endif
    } uop__FOR_ITER_TIER_TWO;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_iter_o;
#endif
    } uop__ITER_CHECK_LIST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_iter_o;
#endif
#if (defined(_Py_TIER2))
        _PyListIterObject * s3_it;
#endif
#if (defined(_Py_TIER2))
        PyListObject * s4_seq;
#endif
    } uop__GUARD_NOT_EXHAUSTED_LIST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_next;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_iter_o;
#endif
#if (defined(_Py_TIER2))
        _PyListIterObject * s4_it;
#endif
#if (defined(_Py_TIER2))
        PyListObject * s5_seq;
#endif
    } uop__ITER_NEXT_LIST_TIER_TWO;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_iter_o;
#endif
    } uop__ITER_CHECK_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_iter_o;
#endif
#if (defined(_Py_TIER2))
        _PyTupleIterObject * s3_it;
#endif
#if (defined(_Py_TIER2))
        PyTupleObject * s4_seq;
#endif
    } uop__GUARD_NOT_EXHAUSTED_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_next;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_iter_o;
#endif
#if (defined(_Py_TIER2))
        _PyTupleIterObject * s4_it;
#endif
#if (defined(_Py_TIER2))
        PyTupleObject * s5_seq;
#endif
    } uop__ITER_NEXT_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        _PyRangeIterObject * s2_r;
#endif
    } uop__ITER_CHECK_RANGE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        _PyRangeIterObject * s2_r;
#endif
    } uop__GUARD_NOT_EXHAUSTED_RANGE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_next;
#endif
#if (defined(_Py_TIER2))
        _PyRangeIterObject * s3_r;
#endif
#if (defined(_Py_TIER2))
        long s4_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_res;
#endif
    } uop__ITER_NEXT_RANGE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_iter;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s2_gen_frame;
#endif
#if (defined(_Py_TIER2))
        PyGenObject * s3_gen;
#endif
    } uop__FOR_ITER_GEN_FRAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s2_method_and_self;
#endif
    } uop__INSERT_NULL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_method_and_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_name;
#endif
#if (defined(_Py_TIER2))
        int s3_err;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_owner;
#endif
#if (defined(_Py_TIER2))
        const char * s5_errfmt;
#endif
    } uop__LOAD_SPECIAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_val;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_lasti;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_exit_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_exit_func;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_exc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_tb;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_val_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_exit_func_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s10_original_tb;
#endif
#if (defined(_Py_TIER2))
        PyObject * s11_stack[ 5 ];
#endif
#if (defined(_Py_TIER2))
        int s12_has_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s13_res_o;
#endif
    } uop__WITH_EXCEPT_START;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_exc;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_prev_exc;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_new_exc;
#endif
#if (defined(_Py_TIER2))
        _PyErr_StackItem * s4_exc_info;
#endif
    } uop__PUSH_EXC_INFO;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_owner_o;
#endif
#if (defined(_Py_TIER2))
        PyDictValues * s3_ivs;
#endif
    } uop__GUARD_DORV_VALUES_INST_ATTR_FROM_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        uint32_t s2_keys_version;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s3_owner_cls;
#endif
#if (defined(_Py_TIER2))
        PyHeapTypeObject * s4_owner_heap_type;
#endif
#if (defined(_Py_TIER2))
        PyDictKeysObject * s5_keys;
#endif
    } uop__GUARD_KEYS_VERSION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_descr;
#endif
    } uop__LOAD_ATTR_METHOD_WITH_VALUES;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_descr;
#endif
    } uop__LOAD_ATTR_METHOD_NO_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_descr;
#endif
    } uop__LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_descr;
#endif
    } uop__LOAD_ATTR_NONDESCRIPTOR_NO_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        uint16_t s2_dictoffset;
#endif
#if (defined(_Py_TIER2))
        char * s3_ptr;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_dict;
#endif
    } uop__CHECK_ATTR_METHOD_LAZY_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_owner;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_descr;
#endif
    } uop__LOAD_ATTR_METHOD_LAZY_DICT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_method;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s6_temp;
#endif
    } uop__MAYBE_EXPAND_METHOD;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        int s7_code_flags;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_locals;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s9_temp;
#endif
    } uop__PY_FRAME_GENERAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        uint32_t s2_func_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s4_func;
#endif
    } uop__CHECK_FUNCTION_VERSION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        uint32_t s1_func_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s3_func;
#endif
    } uop__CHECK_FUNCTION_VERSION_INLINE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        uint32_t s3_func_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_func;
#endif
    } uop__CHECK_METHOD_VERSION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callable_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_temp;
#endif
    } uop__EXPAND_METHOD;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
    } uop__CHECK_IS_NOT_PY_CALLABLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s7_arguments;
#endif
#if (defined(_Py_TIER2))
        PyObject * s8_args_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s9_args_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s10_tmp;
#endif
#if (defined(_Py_TIER2))
        int s11__i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s12_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s13_tmp;
#endif
#if (defined(_Py_TIER2))
        int s14__i;
#endif
    } uop__CALL_NON_PY_GENERAL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
    } uop__CHECK_CALL_BOUND_METHOD_EXACT_ARGS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callable_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_temp;
#endif
    } uop__INIT_CALL_BOUND_METHOD_EXACT_ARGS;
    struct {
        unsigned char empty;
    } uop__CHECK_PEP_523;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s4_func;
#endif
#if (defined(_Py_TIER2))
        PyCodeObject * s5_code;
#endif
    } uop__CHECK_FUNCTION_EXACT_ARGS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s3_func;
#endif
#if (defined(_Py_TIER2))
        PyCodeObject * s4_code;
#endif
    } uop__CHECK_STACK_SPACE;
    struct {
        unsigned char empty;
    } uop__CHECK_RECURSION_REMAINING;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
#if (defined(_Py_TIER2))
        int s5_has_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s6_first_non_self_local;
#endif
#if (defined(_Py_TIER2))
        int s7_i;
#endif
    } uop__INIT_CALL_PY_EXACT_ARGS_0;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
#if (defined(_Py_TIER2))
        int s5_has_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s6_first_non_self_local;
#endif
#if (defined(_Py_TIER2))
        int s7_i;
#endif
    } uop__INIT_CALL_PY_EXACT_ARGS_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
#if (defined(_Py_TIER2))
        int s5_has_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s6_first_non_self_local;
#endif
#if (defined(_Py_TIER2))
        int s7_i;
#endif
    } uop__INIT_CALL_PY_EXACT_ARGS_2;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
#if (defined(_Py_TIER2))
        int s5_has_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s6_first_non_self_local;
#endif
#if (defined(_Py_TIER2))
        int s7_i;
#endif
    } uop__INIT_CALL_PY_EXACT_ARGS_3;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
#if (defined(_Py_TIER2))
        int s5_has_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s6_first_non_self_local;
#endif
#if (defined(_Py_TIER2))
        int s7_i;
#endif
    } uop__INIT_CALL_PY_EXACT_ARGS_4;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_new_frame;
#endif
#if (defined(_Py_TIER2))
        int s5_has_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s6_first_non_self_local;
#endif
#if (defined(_Py_TIER2))
        int s7_i;
#endif
    } uop__INIT_CALL_PY_EXACT_ARGS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s1_new_frame;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s2_temp;
#endif
    } uop__PUSH_FRAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_null;
#endif
    } uop__GUARD_NOS_NULL;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
    } uop__GUARD_CALLABLE_TYPE_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_arg;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_arg_o;
#endif
    } uop__CALL_TYPE_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
    } uop__GUARD_CALLABLE_STR_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_arg;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_arg_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
    } uop__CALL_STR_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
    } uop__GUARD_CALLABLE_TUPLE_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_arg;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_arg_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
    } uop__CALL_TUPLE_1;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        uint32_t s3_type_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s5_tp;
#endif
#if (defined(_Py_TIER2))
        PyHeapTypeObject * s6_cls;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s7_init_func;
#endif
#if (defined(_Py_TIER2))
        PyCodeObject * s8_code;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_self_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s10_temp;
#endif
    } uop__CHECK_AND_ALLOCATE_OBJECT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_init;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_init_frame;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s5_shim;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s6_temp;
#endif
    } uop__CREATE_INIT_FRAME;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_should_be_none;
#endif
    } uop__EXIT_INIT_CHECK;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s6_tp;
#endif
#if (defined(_Py_TIER2))
        int s7_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s8_arguments;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_args_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s10_args_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s11_tmp;
#endif
#if (defined(_Py_TIER2))
        int s12__i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s13_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s14_tmp;
#endif
#if (defined(_Py_TIER2))
        int s15__i;
#endif
    } uop__CALL_BUILTIN_CLASS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        PyCFunction s7_cfunc;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s8_arg;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_res_o;
#endif
    } uop__CALL_BUILTIN_O;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s7_arguments;
#endif
#if (defined(_Py_TIER2))
        PyCFunction s8_cfunc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_args_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s10_args_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s11_tmp;
#endif
#if (defined(_Py_TIER2))
        int s12__i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s13_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s14_tmp;
#endif
#if (defined(_Py_TIER2))
        int s15__i;
#endif
    } uop__CALL_BUILTIN_FAST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s7_arguments;
#endif
#if (defined(_Py_TIER2))
        PyCFunctionFastWithKeywords s8_cfunc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_args_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s10_args_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s11_tmp;
#endif
#if (defined(_Py_TIER2))
        int s12__i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s13_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s14_tmp;
#endif
#if (defined(_Py_TIER2))
        int s15__i;
#endif
    } uop__CALL_BUILTIN_FAST_WITH_KEYWORDS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyInterpreterState * s3_interp;
#endif
    } uop__GUARD_CALLABLE_LEN;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_arg;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_arg_o;
#endif
#if (defined(_Py_TIER2))
        Py_ssize_t s6_len_i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s7_res_o;
#endif
    } uop__CALL_LEN;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s7_arguments;
#endif
#if (defined(_Py_TIER2))
        PyInterpreterState * s8_interp;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s9_cls_stackref;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s10_inst_stackref;
#endif
#if (defined(_Py_TIER2))
        int s11_retval;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s12_tmp;
#endif
#if (defined(_Py_TIER2))
        int s13__i;
#endif
    } uop__CALL_ISINSTANCE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_arg;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_self_o;
#endif
#if (defined(_Py_TIER2))
        PyInterpreterState * s6_interp;
#endif
#if (defined(_Py_TIER2))
        int s7_err;
#endif
    } uop__CALL_LIST_APPEND;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s7_arguments;
#endif
#if (defined(_Py_TIER2))
        PyMethodDescrObject * s8_method;
#endif
#if (defined(_Py_TIER2))
        PyMethodDef * s9_meth;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s10_arg_stackref;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s11_self_stackref;
#endif
#if (defined(_Py_TIER2))
        PyCFunction s12_cfunc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s13_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s14_tmp;
#endif
#if (defined(_Py_TIER2))
        int s15__i;
#endif
    } uop__CALL_METHOD_DESCRIPTOR_O;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s7_arguments;
#endif
#if (defined(_Py_TIER2))
        PyMethodDescrObject * s8_method;
#endif
#if (defined(_Py_TIER2))
        PyMethodDef * s9_meth;
#endif
#if (defined(_Py_TIER2))
        PyTypeObject * s10_d_type;
#endif
#if (defined(_Py_TIER2))
        PyObject * s11_self;
#endif
#if (defined(_Py_TIER2))
        int s12_nargs;
#endif
#if (defined(_Py_TIER2))
        PyObject * s13_args_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s14_args_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s15_tmp;
#endif
#if (defined(_Py_TIER2))
        int s16__i;
#endif
#if (defined(_Py_TIER2))
        PyCFunctionFastWithKeywords s17_cfunc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s18_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s19_tmp;
#endif
#if (defined(_Py_TIER2))
        int s20__i;
#endif
    } uop__CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        PyMethodDescrObject * s7_method;
#endif
#if (defined(_Py_TIER2))
        PyMethodDef * s8_meth;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s9_self_stackref;
#endif
#if (defined(_Py_TIER2))
        PyObject * s10_self;
#endif
#if (defined(_Py_TIER2))
        PyCFunction s11_cfunc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s12_res_o;
#endif
    } uop__CALL_METHOD_DESCRIPTOR_NOARGS;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s6_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s7_arguments;
#endif
#if (defined(_Py_TIER2))
        PyMethodDescrObject * s8_method;
#endif
#if (defined(_Py_TIER2))
        PyMethodDef * s9_meth;
#endif
#if (defined(_Py_TIER2))
        PyObject * s10_self;
#endif
#if (defined(_Py_TIER2))
        int s11_nargs;
#endif
#if (defined(_Py_TIER2))
        PyObject * s12_args_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s13_args_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s14_tmp;
#endif
#if (defined(_Py_TIER2))
        int s15__i;
#endif
#if (defined(_Py_TIER2))
        PyCFunctionFast s16_cfunc;
#endif
#if (defined(_Py_TIER2))
        PyObject * s17_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s18_tmp;
#endif
#if (defined(_Py_TIER2))
        int s19__i;
#endif
    } uop__CALL_METHOD_DESCRIPTOR_FAST;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_self;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_method;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s6_temp;
#endif
    } uop__MAYBE_EXPAND_METHOD_KW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_kwnames;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s2_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_callable;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s5_new_frame;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s7_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s8_arguments;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_kwnames_o;
#endif
#if (defined(_Py_TIER2))
        int s10_positional_args;
#endif
#if (defined(_Py_TIER2))
        int s11_code_flags;
#endif
#if (defined(_Py_TIER2))
        PyObject * s12_locals;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s13_temp;
#endif
    } uop__PY_FRAME_KW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        uint32_t s2_func_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s4_func;
#endif
    } uop__CHECK_FUNCTION_VERSION_KW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        uint32_t s3_func_version;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_callable_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_func;
#endif
    } uop__CHECK_METHOD_VERSION_KW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_callable_s;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_callable_o;
#endif
    } uop__EXPAND_METHOD_KW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callable;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_callable_o;
#endif
    } uop__CHECK_IS_NOT_PY_CALLABLE_KW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_kwnames;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s2_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_self_or_null;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s4_callable;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_callable_o;
#endif
#if (defined(_Py_TIER2))
        int s7_total_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef * s8_arguments;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_args_o_temp[ 11 ];
#endif
#if (defined(_Py_TIER2))
        PyObject * * s10_args_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s11_tmp;
#endif
#if (defined(_Py_TIER2))
        int s12__i;
#endif
#if (defined(_Py_TIER2))
        PyObject * s13_kwnames_o;
#endif
#if (defined(_Py_TIER2))
        int s14_positional_args;
#endif
#if (defined(_Py_TIER2))
        PyObject * s15_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s16_tmp;
#endif
#if (defined(_Py_TIER2))
        int s17__i;
#endif
    } uop__CALL_KW_NON_PY;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_callargs;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_func;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_callargs_o;
#endif
#if (defined(_Py_TIER2))
        int s4_err;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_tuple_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s6_temp;
#endif
    } uop__MAKE_CALLARGS_A_TUPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_codeobj_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_func;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_codeobj;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s4_func_obj;
#endif
    } uop__MAKE_FUNCTION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_func_in;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_attr_st;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_func_out;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_func;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_attr;
#endif
#if (defined(_Py_TIER2))
        size_t s6_offset;
#endif
#if (defined(_Py_TIER2))
        PyObject * * s7_ptr;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s8_func_obj;
#endif
#if (defined(_Py_TIER2))
        PyObject * s9_fixed_qualname;
#endif
    } uop__SET_FUNCTION_ATTRIBUTE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_res;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s2_func;
#endif
#if (defined(_Py_TIER2))
        PyGenObject * s3_gen;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s4_gen_frame;
#endif
#if (defined(_Py_TIER2))
        _PyInterpreterFrame * s5_prev;
#endif
    } uop__RETURN_GENERATOR;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef * s1_args;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_slice;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_start_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_stop_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_step_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_slice_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
#if (defined(_Py_TIER2))
        int s8__i;
#endif
    } uop__BUILD_SLICE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_result;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_result_o;
#endif
    } uop__CONVERT_VALUE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_value_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_res_o;
#endif
    } uop__FORMAT_SIMPLE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_fmt_spec;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s5_tmp;
#endif
    } uop__FORMAT_WITH_SPEC;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_bottom;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_top;
#endif
    } uop__COPY;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_rhs;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_lhs;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_res;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_lhs_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s5_rhs_o;
#endif
#if (defined(_Py_TIER2))
        PyObject * s6_res_o;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s7_tmp;
#endif
    } uop__BINARY_OP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_top;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_bottom;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_temp;
#endif
    } uop__SWAP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_flag;
#endif
#if (defined(_Py_TIER2))
        int s2_is_true;
#endif
    } uop__GUARD_IS_TRUE_POP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_flag;
#endif
#if (defined(_Py_TIER2))
        int s2_is_false;
#endif
    } uop__GUARD_IS_FALSE_POP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_val;
#endif
#if (defined(_Py_TIER2))
        int s2_is_none;
#endif
    } uop__GUARD_IS_NONE_POP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_val;
#endif
#if (defined(_Py_TIER2))
        int s2_is_none;
#endif
    } uop__GUARD_IS_NOT_NONE_POP;
    struct {
        unsigned char empty;
    } uop__JUMP_TO_TOP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_instr_ptr;
#endif
    } uop__SET_IP;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        uint32_t s1_framesize;
#endif
    } uop__CHECK_STACK_SPACE_OPERAND;
    struct {
        unsigned char empty;
    } uop__SAVE_RETURN_OFFSET;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_exit_p;
#endif
#if (defined(_Py_TIER2))
        _PyExitData * s2_exit;
#endif
#if (defined(_Py_TIER2))
        PyCodeObject * s3_code;
#endif
#if (defined(_Py_TIER2))
        _Py_CODEUNIT * s4_target;
#endif
#if (defined(_Py_TIER2))
        _Py_BackoffCounter s5_temperature;
#endif
#if (defined(_Py_TIER2))
        _PyExecutorObject * s6_executor;
#endif
#if (defined(_Py_TIER2))
        int s7_chain_depth;
#endif
#if (defined(_Py_TIER2))
        int s8_optimized;
#endif
    } uop__EXIT_TRACE;
    struct {
        unsigned char empty;
    } uop__CHECK_VALIDITY;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_ptr;
#endif
    } uop__LOAD_CONST_INLINE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_pop;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_ptr;
#endif
    } uop__POP_TOP_LOAD_CONST_INLINE;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s2_ptr;
#endif
    } uop__LOAD_CONST_INLINE_BORROW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_pop;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s3_ptr;
#endif
    } uop__POP_TOP_LOAD_CONST_INLINE_BORROW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        _PyStackRef s1_pop2;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s2_pop1;
#endif
#if (defined(_Py_TIER2))
        _PyStackRef s3_value;
#endif
#if (defined(_Py_TIER2))
        PyObject * s4_ptr;
#endif
    } uop__POP_TWO_LOAD_CONST_INLINE_BORROW;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        uint32_t s1_func_version;
#endif
#if (defined(_Py_TIER2))
        PyFunctionObject * s2_func;
#endif
    } uop__CHECK_FUNCTION;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        PyObject * s1_executor;
#endif
    } uop__START_EXECUTOR;
    struct {
        unsigned char empty;
    } uop__MAKE_WARM;
    struct {
        unsigned char empty;
    } uop__FATAL_ERROR;
    struct {
        unsigned char empty;
    } uop__DEOPT;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        uint32_t s1_target;
#endif
    } uop__ERROR_POP_N;
    struct {
        unsigned char empty;
#if (defined(_Py_TIER2))
        uintptr_t s1_eval_breaker;
#endif
    } uop__TIER2_RESUME_CHECK;
    struct {
        unsigned char empty;
    } dispatch;
    struct {
        unsigned char empty;
    } tier2_dispatch;
};
