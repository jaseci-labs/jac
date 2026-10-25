import from c {
    glob _PyOpcode_Deopt: u8,
         _PyOpcode_Caches: u8,
         PyBaseObject_Type: PyTypeObject; obj MonitoringSlots {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut MonitoringSlots) -> int;  obj MonitoringTraceCall {
        has call:
            Callable[[ptr[PyObject], ptr[PyObject], i32, ptr[PyObject]], i32] = 0;
    }  obj LegacyBranchEventHandler {
        has ob_base: _object,
            vectorcall:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], u64, ptr[PyObject]],
                    ptr[PyObject]
                ],
            handler: ptr[PyObject],
            right: bool,
            tool_id: i32;
    }  obj BranchesIterator {
        has ob_base: _object,
            bi_code: ptr[PyObject],
            bi_offset: i32;
    }  def _PyEval_StopTheWorld(interp: ptr[u8]);  def _PyEval_StartTheWorld(
        interp: ptr[u8]
    );  def _PyErr_GetRaisedException(tstate: ptr[PyThreadState]) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyCode_InitAddressRange(co: ptr[PyObject], bounds: ptr[u8]) -> i32;  def _PyCode_CheckLineNumber(
        lasti: i32, bounds: ptr[u8]
    ) -> i32;  def _PyFrame_MakeAndSetFrameObject(frame: ptr[u8]) -> ptr[PyObject];  def _PyModule_CreateInitialized(
        module: ptr[PyModuleDef], module_api_version: i32
    ) -> ptr[PyObject];  def _PyNamespace_New(kwds: ptr[PyObject]) -> ptr[PyObject];  def _PyTuple_FromArraySteal(
        src: ptr[ptr[PyObject]], n: i64
    ) -> ptr[PyObject];
}

glob:priv NO_LINE: Final[i32] = -2,
     MONITORING_VERSION_INCREMENT: Final[u32] = 256,
     C_RETURN_EVENTS: Final[i32] = 196608,
     C_CALL_EVENTS: Final[i32] = 196624,
     LINE_DATA_ENTRY_SIZE: Final[u64] = 2;

def mon_ptr(monitoring: ptr[u8], offset: i64) -> ptr[u8];

def mon_set_ptr(monitoring: ptr[u8], offset: i64, value: ptr[u8]);

def code_monitoring(code: ptr[PyObject]) -> ptr[u8];

def code_units(code: ptr[PyObject]) -> ptr[u16];

def code_len(code: ptr[PyObject]) -> i32;

def code_i32(code: ptr[PyObject], offset: i64) -> i32;

def code_instrumentation_version(code: ptr[PyObject]) -> u64;

def tstate_interp_of(tstate: ptr[PyThreadState]) -> ptr[u8];

def iframe_instr_ptr(frame: ptr[u8]) -> ptr[u16];

def tstate_i32(tstate: ptr[PyThreadState], offset: i64) -> ptr[i32];

def interp_obj_slot(interp: ptr[u8], offset: i64, index: i64) -> ptr[ptr[PyObject]];

def callable_slot(interp: ptr[u8], tool: i32, event: i32) -> ptr[ptr[PyObject]];

def tool_name_slot(interp: ptr[u8], tool_id: i32) -> ptr[ptr[PyObject]];

def interp_tool_version(interp: ptr[u8], tool_id: i32) -> ptr[u64];

def global_tools(interp: ptr[u8], event: i32) -> u8;

def disable_object -> ptr[PyObject];

def opcode_deopt(opcode: i32) -> i32;

def opcode_caches(opcode: i32) -> i32;

def event_for_opcode(opcode: i32) -> i32;

def de_instrument_of(opcode: i32) -> i32;

def instrumented_opcode(opcode: i32) -> i32;

def event_name(event: i32) -> ptr[u8];

def unit_code(unit: u16) -> i32;

def unit_arg(unit: u16) -> i32;

def base_opcode(code: ptr[PyObject], i: i32) -> i32;

def bit8(tool: i32) -> u8;

def warmup_counter -> u16;

def popcount32(x_in: u32) -> i32;

def bit_length(x_in: u64) -> i32;

def opcode_has_event(opcode: i32) -> bool;

def is_instrumented(opcode: i32) -> bool;

def monitors_read(p: ptr[u8]) -> tuple[u64, u64];

def monitors_write(p: ptr[u8], lo: u64, hi: u64);

def monitors_tool(lo: u64, hi: u64, event: i32) -> u8;

def monitors_are_empty(lo: u64, hi: u64) -> bool;

def multiple_tools(lo: u64, hi: u64) -> bool;

def get_local_events(m: ptr[u8], tool_id: i32) -> u32;

def get_events(m: ptr[u8], tool_id: i32) -> u32;

def set_tool_bits(m: ptr[u8], count: i32, tool_id: i32, events: u32);

def set_events(m: ptr[u8], tool_id: i32, events: u32);

def set_local_events(m: ptr[u8], tool_id: i32, events: u32);

def compute_line_delta(code: ptr[PyObject], line: i32) -> i32;

def compute_line(code: ptr[PyObject], line_delta: i32) -> i32;

def line_entry(line_data: ptr[u8], index: i32) -> ptr[u8];

def get_original_opcode(line_data: ptr[u8], index: i32) -> i32;

def get_original_opcode_ptr(line_data: ptr[u8], index: i32) -> ptr[u8];

def set_original_opcode(line_data: ptr[u8], index: i32, opcode: i32);

def get_line_delta(line_data: ptr[u8], index: i32) -> i32;

def set_line_delta(line_data: ptr[u8], index: i32, line_delta: i32);

def de_instrument(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32, event: i32
);

def de_instrument_line(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
);

def de_instrument_per_instruction(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
);

def instrument(code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32);

def instrument_line(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
);

def instrument_per_instruction(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
);

def remove_tools(code: ptr[PyObject], offset: i32, event: i32, tools: i32);

def remove_line_tools(code: ptr[PyObject], offset: i32, tools: i32);

def add_tools(code: ptr[PyObject], offset: i32, event: i32, tools: i32);

def add_line_tools(code: ptr[PyObject], offset: i32, tools: i32);

def add_per_instruction_tools(code: ptr[PyObject], offset: i32, tools: i32);

def remove_per_instruction_tools(code: ptr[PyObject], offset: i32, tools: i32);

def call_one_instrument(
    interp: ptr[u8],
    tstate: ptr[PyThreadState],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    tool: i32,
    event: i32
) -> i32;

def most_significant_bit(bits: u8) -> i32;

def global_version(interp: ptr[u8]) -> u32;

def set_version_raw(addr: int, version: u32);

def set_global_version(tstate: ptr[PyThreadState], version: u32);

def is_version_up_to_date(code: ptr[PyObject], interp: ptr[u8]) -> bool;

def get_tools_for_instruction(
    code: ptr[PyObject], interp: ptr[u8], i: i32, event_in: i32
) -> u8;

def call_instrumentation_vector(
    instr: ptr[u16],
    tstate: ptr[PyThreadState],
    event: i32,
    frame: ptr[u8],
    arg2: ptr[u16],
    nargs: i64,
    args: ptr[ptr[PyObject]]
) -> i32;

def call_instrumentation_vector_protected(
    tstate: ptr[PyThreadState],
    event: i32,
    frame: ptr[u8],
    instr: ptr[u16],
    nargs: i64,
    args: ptr[ptr[PyObject]]
);

def get_frame_object(frame: ptr[u8]) -> ptr[PyObject];

def call_line_tools(
    tstate: ptr[PyThreadState],
    interp: ptr[u8],
    code: ptr[PyObject],
    monitoring: ptr[u8],
    frame: ptr[u8],
    i: i32,
    line: i32
) -> i32;

def initialize_tools(code: ptr[PyObject]);

def initialize_lines(line_data: ptr[u8], code: ptr[PyObject], bytes_per_entry: i32);

def mark_jump_targets(
    line_data: ptr[u8], code: ptr[PyObject], code_length: i32, firsttraceable: i32
);

def mark_exception_handlers(line_data: ptr[u8], code: ptr[PyObject]);

def initialize_line_tools(code: ptr[PyObject], line_events: u8);

def allocate_instrumentation_data(code: ptr[PyObject]) -> i32;

def line_bytes_per_entry(code: ptr[PyObject], code_length: i32) -> i32;

def update_instrumentation_data(code: ptr[PyObject], interp: ptr[u8]) -> i32;

def apply_event_changes(
    code: ptr[PyObject],
    code_length: i32,
    new_lo: u64,
    new_hi: u64,
    removed_lo: u64,
    removed_hi: u64
);

def force_instrument_lock_held(code: ptr[PyObject], interp: ptr[u8]) -> i32;

def instrument_lock_held(code: ptr[PyObject], interp: ptr[u8]) -> i32;

def instrument_all_executing_code_objects(interp: ptr[u8]) -> i32;

def check_tool(interp: ptr[u8], tool_id: i32) -> i32;

def check_valid_tool(tool_id: i32) -> i32;

def code_check(op: ptr[PyObject]) -> bool;

def monitoring_use_tool_id_impl(
    module: ptr[PyObject], tool_id: i32, name: ptr[PyObject]
) -> ptr[PyObject];

def monitoring_clear_tool_id_impl(
    module: ptr[PyObject], tool_id: i32
) -> ptr[PyObject];

def monitoring_free_tool_id_impl(module: ptr[PyObject], tool_id: i32) -> ptr[PyObject];

def monitoring_get_tool_impl(module: ptr[PyObject], tool_id: i32) -> ptr[PyObject];

def monitoring_register_callback_impl(
    module: ptr[PyObject], tool_id: i32, event: i32, func_in: ptr[PyObject]
) -> ptr[PyObject];

def monitoring_get_events_impl(module: ptr[PyObject], tool_id: i32) -> i32;

def normalize_event_set(event_set_in: i32) -> i32;

def monitoring_set_events_impl(
    module: ptr[PyObject], tool_id: i32, event_set_in: i32
) -> ptr[PyObject];

def monitoring_get_local_events_impl(
    module: ptr[PyObject], tool_id: i32, code: ptr[PyObject]
) -> i32;

def monitoring_set_local_events_impl(
    module: ptr[PyObject], tool_id: i32, code: ptr[PyObject], event_set_in: i32
) -> ptr[PyObject];

def monitoring_restart_events_impl(module: ptr[PyObject]) -> ptr[PyObject];

def add_power2_constant(obj_: ptr[PyObject], name: ptr[u8], i: i32) -> i32;

def monitoring__all_events_impl(module: ptr[PyObject]) -> ptr[PyObject];

def arg_int(arg: ptr[PyObject]) -> tuple[bool, i32];

def monitoring_use_tool_id(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def monitoring_clear_tool_id(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def monitoring_free_tool_id(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def monitoring_get_tool(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def monitoring_register_callback(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def monitoring_get_events(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def monitoring_set_events(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def monitoring_get_local_events(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def monitoring_set_local_events(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def monitoring_restart_events(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def monitoring__all_events(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def set_int_attr(obj_: ptr[PyObject], name: ptr[u8], value: i32) -> i32;

def capi_call_instrumentation(
    state: ptr[u8],
    codelike: ptr[PyObject],
    offset: i32,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    event: i32
) -> i32;

def capi_fire(
    state: ptr[u8],
    codelike: ptr[PyObject],
    offset: i32,
    arg0: ptr[PyObject],
    arg1: ptr[PyObject],
    nargs: i64,
    event: i32
) -> i32;

def exception_event_setup(event: i32) -> tuple[i32, ptr[PyObject]];

def exception_event_teardown(err: i32, exc: ptr[PyObject]) -> i32;

def capi_fire_exception(
    state: ptr[u8], codelike: ptr[PyObject], offset: i32, event: i32
) -> i32;

def dealloc_branch_handler(op: ptr[PyObject]);

def trunc_half(x: i32) -> i32;

def branch_handler_vectorcall(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def make_branch_handler(
    tool_id: i32, handler: ptr[PyObject], right: bool
) -> ptr[PyObject];

def int_triple(a: i32, b: i32, c: i32) -> ptr[PyObject];

def branchesiter_next(op: ptr[PyObject]) -> ptr[PyObject];

def branchesiter_dealloc(op: ptr[PyObject]);

import from c {
    glob _PyInstrumentation_DISABLE: _object = _object(
             ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
             ob_type=addressof(PyBaseObject_Type)
         ),
         _PyInstrumentation_MISSING: _object = _object(
             ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
             ob_type=addressof(PyBaseObject_Type)
         ); glob:priv EVENT_FOR_OPCODE: list[i8] = [
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(4),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(10),
             i8(10),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(8),
             i8(0),
             i8(9),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(2),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(4),
             i8(0),
             i8(0),
             i8(4),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(9),
             i8(0),
             i8(8),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(7),
             i8(0),
             i8(7),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(4),
             i8(0),
             i8(0),
             i8(0),
             i8(9),
             i8(9),
             i8(9),
             i8(9),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(3),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(-1),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(0),
             i8(10),
             i8(9),
             i8(10),
             i8(8),
             i8(0),
             i8(7),
             i8(8),
             i8(9),
             i8(9),
             i8(9),
             i8(9),
             i8(0),
             i8(2),
             i8(3),
             i8(0),
             i8(4),
             i8(4),
             i8(4),
             i8(4),
             i8(7),
             i8(0),
             i8(0)
         ],
         DE_INSTRUMENT: list[u8] = [
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(9),
             u8(30),
             u8(10),
             u8(70),
             u8(0),
             u8(77),
             u8(28),
             u8(103),
             u8(100),
             u8(101),
             u8(102),
             u8(128),
             u8(35),
             u8(120),
             u8(68),
             u8(96),
             u8(52),
             u8(55),
             u8(4),
             u8(75),
             u8(0),
             u8(0)
         ],
         INSTRUMENTED_OPCODES: list[u8] = [
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(252),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(234),
             u8(236),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(240),
             u8(0),
             u8(235),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(246),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(250),
             u8(0),
             u8(0),
             u8(251),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(248),
             u8(0),
             u8(237),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(253),
             u8(0),
             u8(239),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(249),
             u8(0),
             u8(0),
             u8(0),
             u8(242),
             u8(243),
             u8(244),
             u8(241),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(247),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(245),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(234),
             u8(235),
             u8(236),
             u8(237),
             u8(238),
             u8(239),
             u8(240),
             u8(241),
             u8(242),
             u8(243),
             u8(244),
             u8(245),
             u8(246),
             u8(247),
             u8(248),
             u8(249),
             u8(250),
             u8(251),
             u8(252),
             u8(253),
             u8(254),
             u8(0)
         ],
         MOST_SIGNIFICANT_BITS: list[i8] = [
             i8(-1),
             i8(0),
             i8(1),
             i8(1),
             i8(2),
             i8(2),
             i8(2),
             i8(2),
             i8(3),
             i8(3),
             i8(3),
             i8(3),
             i8(3),
             i8(3),
             i8(3),
             i8(3)
         ],
         event_names: list[ptr[u8]] = [
             ptr[u8]("PY_START"),
             ptr[u8]("PY_RESUME"),
             ptr[u8]("PY_RETURN"),
             ptr[u8]("PY_YIELD"),
             ptr[u8]("CALL"),
             ptr[u8]("LINE"),
             ptr[u8]("INSTRUCTION"),
             ptr[u8]("JUMP"),
             ptr[u8]("BRANCH_LEFT"),
             ptr[u8]("BRANCH_RIGHT"),
             ptr[u8]("STOP_ITERATION"),
             ptr[u8]("RAISE"),
             ptr[u8]("EXCEPTION_HANDLED"),
             ptr[u8]("PY_UNWIND"),
             ptr[u8]("PY_THROW"),
             ptr[u8]("RERAISE"),
             ptr[u8]("C_RETURN"),
             ptr[u8]("C_RAISE"),
             ptr[u8]("BRANCH")
         ],
         methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("use_tool_id"),
                 ml_meth=ptr(monitoring_use_tool_id),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8]("use_tool_id($module, tool_id, name, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("clear_tool_id"),
                 ml_meth=ptr(monitoring_clear_tool_id),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("clear_tool_id($module, tool_id, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("free_tool_id"),
                 ml_meth=ptr(monitoring_free_tool_id),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("free_tool_id($module, tool_id, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_tool"),
                 ml_meth=ptr(monitoring_get_tool),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("get_tool($module, tool_id, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("register_callback"),
                 ml_meth=ptr(monitoring_register_callback),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "register_callback($module, tool_id, event, func, /)\n--\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_events"),
                 ml_meth=ptr(monitoring_get_events),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("get_events($module, tool_id, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_events"),
                 ml_meth=ptr(monitoring_set_events),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8]("set_events($module, tool_id, event_set, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_local_events"),
                 ml_meth=ptr(monitoring_get_local_events),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8]("get_local_events($module, tool_id, code, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_local_events"),
                 ml_meth=ptr(monitoring_set_local_events),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "set_local_events($module, tool_id, code, event_set, /)\n--\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("restart_events"),
                 ml_meth=ptr(monitoring_restart_events),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("restart_events($module, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_all_events"),
                 ml_meth=ptr(monitoring__all_events),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("_all_events($module, /)\n--\n\n")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         monitoring_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("sys.monitoring"),
             m_size=-1,
             m_methods=addressof(methods)
         ),
         _PyLegacyBranchEventHandler_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("sys.monitoring.branch_event_handler"),
             tp_basicsize=40,
             tp_dealloc=dealloc_branch_handler,
             tp_vectorcall_offset=16,
             tp_call=PyVectorcall_Call,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_HAVE_VECTORCALL
                 | Py_TPFLAGS_DISALLOW_INSTANTIATION
         ),
         _PyBranchesIterator: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("line_iterator"),
             tp_basicsize=32,
             tp_dealloc=branchesiter_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_iter=PyObject_SelfIter,
             tp_iternext=branchesiter_next,
             tp_free=PyObject_Free
         );
}

import from c {
    def _PyInstruction_GetLength(code: ptr[PyObject], offset: i32) -> i32 {
        return 1 + opcode_caches(unit_code(_Py_GetBaseCodeUnit(code, offset)));
    }  def _Py_GetBaseCodeUnit(code: ptr[PyObject], i: i32) -> u16 {
        inst = (code_units(code) + i64(i)).view(1)[0];
        high = inst & u16(65280);
        opcode = unit_code(inst);
        if opcode < MIN_INSTRUMENTED_OPCODE {
            return high | u16(opcode_deopt(opcode));
        }
        if opcode == ENTER_EXECUTOR {
            executors = ptr[ptr[u8]](ptr[u8](code) + PyCodeObject_EXECUTORS).view(1)[0];
            executor = ptr[ptr[u8]](
                executors + _PyExecutorArray_EXECUTORS + i64(unit_arg(inst)) * 8
            ).view(
                1
            )[0];
            vm_opcode = opcode_deopt(
                i32((executor + _PyExecutorObject_VM_DATA_OPCODE).view(1)[0])
            );
            vm_oparg = u16((executor + _PyExecutorObject_VM_DATA_OPARG).view(1)[0]);
            return (vm_oparg << u16(8)) | u16(vm_opcode);
        }
        monitoring = code_monitoring(code);
        if opcode == INSTRUMENTED_LINE {
            opcode = get_original_opcode(
                mon_ptr(monitoring, _PyCoMonitoringData_LINES), i
            );
        }
        if opcode == INSTRUMENTED_INSTRUCTION {
            opcode = i32(
                (
                    mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES)
                    + i64(i)
                ).view(
                    1
                )[0]
            );
        }
        deinstrumented = de_instrument_of(opcode);
        if deinstrumented != 0 {
            return high | u16(deinstrumented);
        }
        return high | u16(opcode_deopt(opcode));
    }  def _Py_call_instrumentation(
        tstate: ptr[PyThreadState], event: i32, frame: ptr[u8], instr: ptr[u16]
    ) -> i32 {
        slots: own MonitoringSlots = MonitoringSlots();
        args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        return call_instrumentation_vector(instr, tstate, event, frame, instr, 2, args);
    }  def _Py_call_instrumentation_arg(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg: ptr[PyObject]
    ) -> i32 {
        slots: own MonitoringSlots = MonitoringSlots();
        args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        (args + 3).view(1)[0] = arg;
        return call_instrumentation_vector(instr, tstate, event, frame, instr, 3, args);
    }  def _Py_call_instrumentation_2args(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg0: ptr[PyObject],
        arg1: ptr[PyObject]
    ) -> i32 {
        slots: own MonitoringSlots = MonitoringSlots();
        args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        (args + 3).view(1)[0] = arg0;
        (args + 4).view(1)[0] = arg1;
        return call_instrumentation_vector(instr, tstate, event, frame, instr, 4, args);
    }  def _Py_call_instrumentation_jump(
        instr: ptr[u16],
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        src: ptr[u16],
        dest: ptr[u16]
    ) -> ptr[u16] {
        to = i32.wrap((int(dest) - int(iframe_bytecode(frame))) // 2);
        to_obj = PyLong_FromLong(i64(to * 2));
        if not to_obj {
            return ptr[u16]();
        }
        slots: own MonitoringSlots = MonitoringSlots();
        args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        (args + 3).view(1)[0] = to_obj;
        instr_ptr = iframe_instr_ptr(frame);
        err = call_instrumentation_vector(instr, tstate, event, frame, src, 3, args);
        object_decref(to_obj);
        if err != 0 {
            return ptr[u16]();
        }
        current = iframe_instr_ptr(frame);
        if current != instr_ptr {
            return current;
        }
        return dest;
    }  def _Py_call_instrumentation_exc2(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg0: ptr[PyObject],
        arg1: ptr[PyObject]
    ) {
        slots: own MonitoringSlots = MonitoringSlots();
        args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        (args + 3).view(1)[0] = arg0;
        (args + 4).view(1)[0] = arg1;
        call_instrumentation_vector_protected(tstate, event, frame, instr, 4, args);
    }  def _Py_Instrumentation_GetLine(
        code: ptr[PyObject], line_data: ptr[u8], index: i32
    ) -> i32 {
        return compute_line(code, get_line_delta(line_data, index));
    }  def _Py_call_instrumentation_line(
        tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16], prev: ptr[u16]
    ) -> i32 {
        code = iframe_code(frame);
        bytecode = ptr[u16](iframe_bytecode(frame));
        i = i32.wrap((int(instr) - int(bytecode)) // 2);
        monitoring = code_monitoring(code);
        line_data = mon_ptr(monitoring, _PyCoMonitoringData_LINES);
        interp = tstate_interp_of(tstate);
        line = _Py_Instrumentation_GetLine(code, line_data, i);
        prev_index = i32.wrap((int(prev) - int(bytecode)) // 2);
        prev_line = _Py_Instrumentation_GetLine(code, line_data, prev_index);
        hidden = False;
        if prev_line == line {
            prev_opcode = i32(ptr[u8](bytecode + i64(prev_index)).view(1)[0]);
            if prev_opcode != RESUME and prev_opcode != INSTRUMENTED_RESUME {
                hidden = True;
            }
        }
        if not hidden {
            if call_line_tools(tstate, interp, code, monitoring, frame, i, line) < 0 {
                return -1;
            }
        }
        return get_original_opcode(line_data, i);
    }  def _Py_call_instrumentation_instruction(
        tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16]
    ) -> i32 {
        code = iframe_code(frame);
        offset = i32.wrap((int(instr) - int(iframe_bytecode(frame))) // 2);
        instrumentation_data = code_monitoring(code);
        next_opcode = i32(
            (
                mon_ptr(
                    instrumentation_data, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES
                )
                + i64(offset)
            ).view(
                1
            )[0]
        );
        if tstate_i32(tstate, PyThreadState_TRACING).view(1)[0] != 0 {
            return next_opcode;
        }
        interp = tstate_interp_of(tstate);
        tools: u8 = 0;
        per_instruction_tools = mon_ptr(
            instrumentation_data, _PyCoMonitoringData_PER_INSTRUCTION_TOOLS
        );
        if per_instruction_tools {
            tools = (per_instruction_tools + i64(offset)).view(1)[0];
        } else {
            tools = global_tools(interp, PY_MONITORING_EVENT_INSTRUCTION)
                | (
                    instrumentation_data
                    + _PyCoMonitoringData_LOCAL_MONITORS
                    + i64(PY_MONITORING_EVENT_INSTRUCTION)
                ).view(
                    1
                )[0];
        }
        offset_obj = PyLong_FromLong(i64(offset * 2));
        if not offset_obj {
            return -1;
        }
        slots: own MonitoringSlots = MonitoringSlots();
        args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        (args + 1).view(1)[0] = code;
        (args + 2).view(1)[0] = offset_obj;
        while tools != u8(0) {
            tool = most_significant_bit(tools);
            tools = tools & ~bit8(tool);
            res = call_one_instrument(
                interp,
                tstate,
                args + 1,
                u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET,
                tool,
                PY_MONITORING_EVENT_INSTRUCTION
            );
            if res < 0 {
                object_decref(offset_obj);
                return -1;
            }
            if res > 0 {
                _PyEval_StopTheWorld(interp);
                remove_per_instruction_tools(code, offset, 1 << tool);
                _PyEval_StartTheWorld(interp);
            }
        }
        object_decref(offset_obj);
        return next_opcode;
    }  def _Py_Instrument(code: ptr[PyObject], interp: ptr[u8]) -> i32 {
        return instrument_lock_held(code, interp);
    }  def _PyMonitoring_SetEvents(tool_id: i32, events: u32) -> i32 {
        tstate = current_tstate();
        interp = tstate_interp_of(tstate);
        if check_tool(interp, tool_id) != 0 {
            return -1;
        }
        existing_events = get_events(interp + PyInterpreterState_MONITORS, tool_id);
        if existing_events == events {
            return 0;
        }
        new_version = wrapping_add(
            global_version(interp), MONITORING_VERSION_INCREMENT
        );
        if new_version == u32(0) {
            PyErr_Format(PyExc_OverflowError, "events set too many times");
            return -1;
        }
        set_events(interp + PyInterpreterState_MONITORS, tool_id, events);
        set_global_version(tstate, new_version);
        return instrument_all_executing_code_objects(interp);
    }  def _PyMonitoring_SetLocalEvents(
        code: ptr[PyObject], tool_id: i32, events: u32
    ) -> i32 {
        interp = current_interp();
        if i64(code_i32(code, PyCodeObject_FIRSTTRACEABLE)) >= object_size(code) {
            PyErr_Format(
                PyExc_SystemError,
                "cannot instrument shim code object '%U'",
                ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_NAME).view(1)[0]
            );
            return -1;
        }
        if check_tool(interp, tool_id) != 0 {
            return -1;
        }
        if allocate_instrumentation_data(code) != 0 {
            return -1;
        }
        monitoring = code_monitoring(code);
        ptr[u64](
            monitoring + _PyCoMonitoringData_TOOL_VERSIONS + i64(tool_id) * 8
        ).view(
            1
        )[0] = interp_tool_version(interp, tool_id).view(1)[0];
        local = monitoring + _PyCoMonitoringData_LOCAL_MONITORS;
        existing_events = get_local_events(local, tool_id);
        if existing_events == events {
            return 0;
        }
        set_local_events(local, tool_id, events);
        return force_instrument_lock_held(code, interp);
    }  def _PyMonitoring_GetLocalEvents(
        code: ptr[PyObject], tool_id: i32, events: ptr[u32]
    ) -> i32 {
        interp = current_interp();
        if check_tool(interp, tool_id) != 0 {
            return -1;
        }
        monitoring = code_monitoring(code);
        if not monitoring {
            events.view(1)[0] = u32(0);
            return 0;
        }
        events.view(1)[0] = get_local_events(
            monitoring + _PyCoMonitoringData_LOCAL_MONITORS, tool_id
        );
        return 0;
    }  def _PyMonitoring_ClearToolId(tool_id: i32) -> i32 {
        interp = current_interp();
        i: i32 = 0;
        while i < _PY_MONITORING_EVENTS {
            func = _PyMonitoring_RegisterCallback(tool_id, i, NULL);
            if func {
                object_decref(func);
            }
            i += 1;
        }
        _PyEval_StopTheWorld(interp);
        if _PyMonitoring_SetEvents(tool_id, u32(0)) < 0 {
            _PyEval_StartTheWorld(interp);
            return -1;
        }
        version = wrapping_add(global_version(interp), MONITORING_VERSION_INCREMENT);
        if version == u32(0) {
            PyErr_Format(PyExc_OverflowError, "events set too many times");
            _PyEval_StartTheWorld(interp);
            return -1;
        }
        interp_tool_version(interp, tool_id).view(1)[0] = u64(version);
        set_global_version(current_tstate(), version);
        res = instrument_all_executing_code_objects(interp);
        _PyEval_StartTheWorld(interp);
        return res;
    }  def _Py_CreateMonitoringObject -> ptr[PyObject] {
        mod = _PyModule_CreateInitialized(
            ptr[PyModuleDef](addressof(monitoring_module)), PYTHON_API_VERSION
        );
        if not mod {
            return NULL;
        }
        if PyObject_SetAttrString(
            mod,
            ptr[u8]("DISABLE"),
            ptr[PyObject](addressof(_PyInstrumentation_DISABLE))
        )
            != 0 {
            object_decref(mod);
            return NULL;
        }
        if PyObject_SetAttrString(
            mod,
            ptr[u8]("MISSING"),
            ptr[PyObject](addressof(_PyInstrumentation_MISSING))
        )
            != 0 {
            object_decref(mod);
            return NULL;
        }
        events = _PyNamespace_New(NULL);
        if not events {
            object_decref(mod);
            return NULL;
        }
        err = PyObject_SetAttrString(mod, ptr[u8]("events"), events);
        object_decref(events);
        if err != 0 {
            object_decref(mod);
            return NULL;
        }
        i: i32 = 0;
        while i < _PY_MONITORING_EVENTS {
            if add_power2_constant(events, event_name(i), i) != 0 {
                object_decref(mod);
                return NULL;
            }
            i += 1;
        }
        zero = PyLong_FromLong(0);
        err = PyObject_SetAttrString(events, ptr[u8]("NO_EVENTS"), zero);
        object_decref(zero);
        if err != 0 {
            object_decref(mod);
            return NULL;
        }
        if set_int_attr(mod, ptr[u8]("DEBUGGER_ID"), PY_MONITORING_DEBUGGER_ID) != 0 {
            object_decref(mod);
            return NULL;
        }
        if set_int_attr(mod, ptr[u8]("COVERAGE_ID"), PY_MONITORING_COVERAGE_ID) != 0 {
            object_decref(mod);
            return NULL;
        }
        if set_int_attr(mod, ptr[u8]("PROFILER_ID"), PY_MONITORING_PROFILER_ID) != 0 {
            object_decref(mod);
            return NULL;
        }
        if set_int_attr(mod, ptr[u8]("OPTIMIZER_ID"), PY_MONITORING_OPTIMIZER_ID)
            != 0 {
            object_decref(mod);
            return NULL;
        }
        return mod;
    }  def PyMonitoring_EnterScope(
        state_array: ptr[u8], version: ptr[u64], event_types: ptr[u8], length: i64
    ) -> i32 {
        interp = current_interp();
        if u64(global_version(interp)) == version.view(1)[0] {
            return 0;
        }
        i: i64 = 0;
        while i < length {
            event = i32((event_types + i).view(1)[0]);
            (state_array + i * PyMonitoringState_SIZE).view(1)[0] = global_tools(
                interp, event
            );
            i += 1;
        }
        version.view(1)[0] = u64(global_version(interp));
        return 0;
    }  def PyMonitoring_ExitScope -> i32 {
        return 0;
    }  def _PyMonitoring_FirePyStartEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire(
            state, codelike, offset, NULL, NULL, 2, PY_MONITORING_EVENT_PY_START
        );
    }  def _PyMonitoring_FirePyResumeEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire(
            state, codelike, offset, NULL, NULL, 2, PY_MONITORING_EVENT_PY_RESUME
        );
    }  def _PyMonitoring_FirePyReturnEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32, retval: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state, codelike, offset, retval, NULL, 3, PY_MONITORING_EVENT_PY_RETURN
        );
    }  def _PyMonitoring_FirePyYieldEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32, retval: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state, codelike, offset, retval, NULL, 3, PY_MONITORING_EVENT_PY_YIELD
        );
    }  def _PyMonitoring_FireCallEvent(
        state: ptr[u8],
        codelike: ptr[PyObject],
        offset: i32,
        callable: ptr[PyObject],
        arg0: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state, codelike, offset, callable, arg0, 4, PY_MONITORING_EVENT_CALL
        );
    }  def _PyMonitoring_FireLineEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32, lineno: i32
    ) -> i32 {
        lno = PyLong_FromLong(i64(lineno));
        if not lno {
            return -1;
        }
        slots: own MonitoringSlots = MonitoringSlots();
        args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        (args + 2).view(1)[0] = lno;
        res = capi_call_instrumentation(
            state, codelike, offset, args, 2, PY_MONITORING_EVENT_LINE
        );
        object_decref(lno);
        return res;
    }  def _PyMonitoring_FireJumpEvent(
        state: ptr[u8],
        codelike: ptr[PyObject],
        offset: i32,
        target_offset: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state, codelike, offset, target_offset, NULL, 3, PY_MONITORING_EVENT_JUMP
        );
    }  def _PyMonitoring_FireBranchEvent(
        state: ptr[u8],
        codelike: ptr[PyObject],
        offset: i32,
        target_offset: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state,
            codelike,
            offset,
            target_offset,
            NULL,
            3,
            PY_MONITORING_EVENT_BRANCH_RIGHT
        );
    }  def _PyMonitoring_FireBranchRightEvent(
        state: ptr[u8],
        codelike: ptr[PyObject],
        offset: i32,
        target_offset: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state,
            codelike,
            offset,
            target_offset,
            NULL,
            3,
            PY_MONITORING_EVENT_BRANCH_RIGHT
        );
    }  def _PyMonitoring_FireBranchLeftEvent(
        state: ptr[u8],
        codelike: ptr[PyObject],
        offset: i32,
        target_offset: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state,
            codelike,
            offset,
            target_offset,
            NULL,
            3,
            PY_MONITORING_EVENT_BRANCH_LEFT
        );
    }  def _PyMonitoring_FireCReturnEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32, retval: ptr[PyObject]
    ) -> i32 {
        return capi_fire(
            state, codelike, offset, retval, NULL, 3, PY_MONITORING_EVENT_C_RETURN
        );
    }  def _PyMonitoring_FirePyThrowEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire_exception(
            state, codelike, offset, PY_MONITORING_EVENT_PY_THROW
        );
    }  def _PyMonitoring_FireRaiseEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire_exception(state, codelike, offset, PY_MONITORING_EVENT_RAISE);
    }  def _PyMonitoring_FireCRaiseEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire_exception(
            state, codelike, offset, PY_MONITORING_EVENT_C_RAISE
        );
    }  def _PyMonitoring_FireReraiseEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire_exception(
            state, codelike, offset, PY_MONITORING_EVENT_RERAISE
        );
    }  def _PyMonitoring_FireExceptionHandledEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire_exception(
            state, codelike, offset, PY_MONITORING_EVENT_EXCEPTION_HANDLED
        );
    }  def _PyMonitoring_FirePyUnwindEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32
    ) -> i32 {
        return capi_fire_exception(
            state, codelike, offset, PY_MONITORING_EVENT_PY_UNWIND
        );
    }  def _PyMonitoring_FireStopIterationEvent(
        state: ptr[u8], codelike: ptr[PyObject], offset: i32, value: ptr[PyObject]
    ) -> i32 {
        PyErr_SetObject(PyExc_StopIteration, value);
        (status, exc) = exception_event_setup(PY_MONITORING_EVENT_STOP_ITERATION);
        if status < 0 {
            return -1;
        }
        err = capi_fire(
            state, codelike, offset, exc, NULL, 3, PY_MONITORING_EVENT_STOP_ITERATION
        );
        object_decref(exc);
        return exception_event_teardown(err, NULL);
    }  def _PyMonitoring_RegisterCallback(
        tool_id: i32, event_id: i32, obj_: ptr[PyObject]
    ) -> ptr[PyObject] {
        res = NULL;
        if event_id == PY_MONITORING_EVENT_BRANCH {
            left = NULL;
            right = NULL;
            if obj_ {
                right = make_branch_handler(tool_id, obj_, True);
                if not right {
                    return NULL;
                }
                left = make_branch_handler(tool_id, obj_, False);
                if not left {
                    object_decref(right);
                    return NULL;
                }
            }
            interp = current_interp();
            _PyEval_StopTheWorld(interp);
            right_slot = callable_slot(
                interp, tool_id, PY_MONITORING_EVENT_BRANCH_RIGHT
            );
            old_right = right_slot.view(1)[0];
            right_slot.view(1)[0] = right;
            left_slot = callable_slot(interp, tool_id, PY_MONITORING_EVENT_BRANCH_LEFT);
            res = left_slot.view(1)[0];
            left_slot.view(1)[0] = left;
            _PyEval_StartTheWorld(interp);
            object_xdecref(old_right);
        } else {
            interp = current_interp();
            _PyEval_StopTheWorld(interp);
            slot = callable_slot(interp, tool_id, event_id);
            res = slot.view(1)[0];
            if obj_ {
                object_incref(obj_);
            }
            slot.view(1)[0] = obj_;
            _PyEval_StartTheWorld(interp);
        }
        if res and object_type(res) == addressof(_PyLegacyBranchEventHandler_Type) {
            wrapper = res;
            res = object_new_ref(
                ptr[LegacyBranchEventHandler](wrapper).view(1)[0].handler
            );
            object_decref(wrapper);
        }
        return res;
    }  def _PyInstrumentation_BranchesIterator(code: ptr[PyObject]) -> ptr[PyObject] {
        bi = PyType_GenericAlloc(ptr[PyObject](addressof(_PyBranchesIterator)), 0);
        if not bi {
            return NULL;
        }
        iterator = ptr[BranchesIterator](bi);
        iterator.view(1)[0].bi_code = object_new_ref(code);
        iterator.view(1)[0].bi_offset = 0;
        return bi;
    }
}

impl mon_ptr(monitoring: ptr[u8], offset: i64) -> ptr[u8] {
    return ptr[ptr[u8]](monitoring + offset).view(1)[0];
}

impl mon_set_ptr(monitoring: ptr[u8], offset: i64, value: ptr[u8]) {
    ptr[ptr[u8]](monitoring + offset).view(1)[0] = value;
}

impl code_monitoring(code: ptr[PyObject]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](code) + PyCodeObject_MONITORING).view(1)[0];
}

impl code_units(code: ptr[PyObject]) -> ptr[u16] {
    return ptr[u16](ptr[u8](code) + PyCodeObject_CODE_ADAPTIVE);
}

impl code_len(code: ptr[PyObject]) -> i32 {
    return i32.wrap(object_size(code));
}

impl code_i32(code: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](code) + offset).view(1)[0];
}

impl code_instrumentation_version(code: ptr[PyObject]) -> u64 {
    return ptr[u64](ptr[u8](code) + PyCodeObject_INSTRUMENTATION_VERSION).view(1)[0];
}

impl tstate_interp_of(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl iframe_instr_ptr(frame: ptr[u8]) -> ptr[u16] {
    return ptr[ptr[u16]](frame + _PyInterpreterFrame_INSTR_PTR).view(1)[0];
}

impl tstate_i32(tstate: ptr[PyThreadState], offset: i64) -> ptr[i32] {
    return ptr[i32](ptr[u8](tstate) + offset);
}

impl interp_obj_slot(interp: ptr[u8], offset: i64, index: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](interp + offset + index * 8);
}

impl callable_slot(interp: ptr[u8], tool: i32, event: i32) -> ptr[ptr[PyObject]] {
    return interp_obj_slot(
        interp,
        PyInterpreterState_MONITORING_CALLABLES,
        i64(tool) * i64(_PY_MONITORING_EVENTS) + i64(event)
    );
}

impl tool_name_slot(interp: ptr[u8], tool_id: i32) -> ptr[ptr[PyObject]] {
    return interp_obj_slot(
        interp, PyInterpreterState_MONITORING_TOOL_NAMES, i64(tool_id)
    );
}

impl interp_tool_version(interp: ptr[u8], tool_id: i32) -> ptr[u64] {
    return ptr[u64](
        interp + PyInterpreterState_MONITORING_TOOL_VERSIONS + i64(tool_id) * 8
    );
}

impl global_tools(interp: ptr[u8], event: i32) -> u8 {
    return (interp + PyInterpreterState_MONITORS + i64(event)).view(1)[0];
}

impl disable_object -> ptr[PyObject] {
    return ptr[PyObject](addressof(_PyInstrumentation_DISABLE));
}

impl opcode_deopt(opcode: i32) -> i32 {
    return i32((addressof(_PyOpcode_Deopt) + i64(opcode)).view(1)[0]);
}

impl opcode_caches(opcode: i32) -> i32 {
    return i32((addressof(_PyOpcode_Caches) + i64(opcode)).view(1)[0]);
}

impl event_for_opcode(opcode: i32) -> i32 {
    return i32((addressof(EVENT_FOR_OPCODE) + i64(opcode)).view(1)[0]);
}

impl de_instrument_of(opcode: i32) -> i32 {
    return i32((addressof(DE_INSTRUMENT) + i64(opcode)).view(1)[0]);
}

impl instrumented_opcode(opcode: i32) -> i32 {
    return i32((addressof(INSTRUMENTED_OPCODES) + i64(opcode)).view(1)[0]);
}

impl event_name(event: i32) -> ptr[u8] {
    return (addressof(event_names) + i64(event)).view(1)[0];
}

impl unit_code(unit: u16) -> i32 {
    return i32(unit & u16(255));
}

impl unit_arg(unit: u16) -> i32 {
    return i32(unit >> u16(8));
}

impl base_opcode(code: ptr[PyObject], i: i32) -> i32 {
    return unit_code(_Py_GetBaseCodeUnit(code, i));
}

impl bit8(tool: i32) -> u8 {
    return u8.wrap(1 << tool);
}

impl warmup_counter -> u16 {
    return u16((ADAPTIVE_WARMUP_VALUE << BACKOFF_BITS) | ADAPTIVE_WARMUP_BACKOFF);
}

impl popcount32(x_in: u32) -> i32 {
    x = x_in;
    n: i32 = 0;
    while x != u32(0) {
        x = x & (x - u32(1));
        n += 1;
    }
    return n;
}

impl bit_length(x_in: u64) -> i32 {
    x = x_in;
    n: i32 = 0;
    while x != u64(0) {
        x = x >> u64(1);
        n += 1;
    }
    return n;
}

impl opcode_has_event(opcode: i32) -> bool {
    return opcode != INSTRUMENTED_LINE and instrumented_opcode(opcode) > 0;
}

impl is_instrumented(opcode: i32) -> bool {
    return opcode != ENTER_EXECUTOR and opcode >= MIN_INSTRUMENTED_OPCODE;
}

impl monitors_read(p: ptr[u8]) -> tuple[u64, u64] {
    lo: u64 = 0;
    hi: u64 = 0;
    i: i64 = 0;
    while i < 8 {
        lo = lo | (u64((p + i).view(1)[0]) << u64(i * 8));
        i += 1;
    }
    while i < i64(_PY_MONITORING_LOCAL_EVENTS) {
        hi = hi | (u64((p + i).view(1)[0]) << u64((i - 8) * 8));
        i += 1;
    }
    return (lo, hi);
}

impl monitors_write(p: ptr[u8], lo: u64, hi: u64) {
    i: i64 = 0;
    while i < 8 {
        (p + i).view(1)[0] = u8.wrap(lo >> u64(i * 8));
        i += 1;
    }
    while i < i64(_PY_MONITORING_LOCAL_EVENTS) {
        (p + i).view(1)[0] = u8.wrap(hi >> u64((i - 8) * 8));
        i += 1;
    }
}

impl monitors_tool(lo: u64, hi: u64, event: i32) -> u8 {
    if event < 8 {
        return u8.wrap(lo >> u64(event * 8));
    }
    return u8.wrap(hi >> u64((event - 8) * 8));
}

impl monitors_are_empty(lo: u64, hi: u64) -> bool {
    return lo == u64(0) and hi == u64(0);
}

impl multiple_tools(lo: u64, hi: u64) -> bool {
    e: i32 = 0;
    while e < _PY_MONITORING_LOCAL_EVENTS {
        if popcount32(u32(monitors_tool(lo, hi, e))) > 1 {
            return True;
        }
        e += 1;
    }
    return False;
}

impl get_local_events(m: ptr[u8], tool_id: i32) -> u32 {
    result: u32 = 0;
    e: i32 = 0;
    while e < _PY_MONITORING_LOCAL_EVENTS {
        if ((i32((m + i64(e)).view(1)[0]) >> tool_id) & 1) != 0 {
            result = result | (u32(1) << u32(e));
        }
        e += 1;
    }
    return result;
}

impl get_events(m: ptr[u8], tool_id: i32) -> u32 {
    result: u32 = 0;
    e: i32 = 0;
    while e < _PY_MONITORING_UNGROUPED_EVENTS {
        if ((i32((m + i64(e)).view(1)[0]) >> tool_id) & 1) != 0 {
            result = result | (u32(1) << u32(e));
        }
        e += 1;
    }
    return result;
}

impl set_tool_bits(m: ptr[u8], count: i32, tool_id: i32, events: u32) {
    e: i32 = 0;
    while e < count {
        tools = m + i64(e);
        active = i32((events >> u32(e)) & u32(1));
        value = i32(tools.view(1)[0]) & ~(1 << tool_id);
        value = value | (active << tool_id);
        tools.view(1)[0] = u8.wrap(value);
        e += 1;
    }
}

impl set_events(m: ptr[u8], tool_id: i32, events: u32) {
    set_tool_bits(m, _PY_MONITORING_UNGROUPED_EVENTS, tool_id, events);
}

impl set_local_events(m: ptr[u8], tool_id: i32, events: u32) {
    set_tool_bits(m, _PY_MONITORING_LOCAL_EVENTS, tool_id, events);
}

impl compute_line_delta(code: ptr[PyObject], line: i32) -> i32 {
    if line < 0 {
        return NO_LINE;
    }
    return line - code_i32(code, PyCodeObject_FIRSTLINENO);
}

impl compute_line(code: ptr[PyObject], line_delta: i32) -> i32 {
    if line_delta == NO_LINE {
        return -1;
    }
    return code_i32(code, PyCodeObject_FIRSTLINENO) + line_delta;
}

impl line_entry(line_data: ptr[u8], index: i32) -> ptr[u8] {
    bytes_per_entry = i64(line_data.view(1)[0]);
    return line_data + _PyCoLineInstrumentationData_DATA + i64(index) * bytes_per_entry;
}

impl get_original_opcode(line_data: ptr[u8], index: i32) -> i32 {
    return i32(line_entry(line_data, index).view(1)[0]);
}

impl get_original_opcode_ptr(line_data: ptr[u8], index: i32) -> ptr[u8] {
    return line_entry(line_data, index);
}

impl set_original_opcode(line_data: ptr[u8], index: i32, opcode: i32) {
    line_entry(line_data, index).view(1)[0] = u8.wrap(opcode);
}

impl get_line_delta(line_data: ptr[u8], index: i32) -> i32 {
    bytes_per_entry = i32(line_data.view(1)[0]);
    p = line_entry(line_data, index) + 1;
    value = u32(p.view(1)[0]);
    idx: i32 = 2;
    while idx < bytes_per_entry {
        p = p + 1;
        shift = (idx - 1) * 8;
        value = value | (u32(p.view(1)[0]) << u32(shift));
        idx += 1;
    }
    return i32.wrap(value) + NO_LINE;
}

impl set_line_delta(line_data: ptr[u8], index: i32, line_delta: i32) {
    bytes_per_entry = i32(line_data.view(1)[0]);
    adjusted = u32.wrap(line_delta - NO_LINE);
    p = line_entry(line_data, index) + 1;
    p.view(1)[0] = u8.wrap(adjusted & u32(255));
    idx: i32 = 2;
    while idx < bytes_per_entry {
        p = p + 1;
        adjusted = adjusted >> u32(8);
        p.view(1)[0] = u8.wrap(adjusted & u32(255));
        idx += 1;
    }
}

impl de_instrument(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32, event: i32
) {
    instr = bytecode + i64(i);
    opcode_ptr = ptr[u8](instr);
    opcode = i32(opcode_ptr.view(1)[0]);
    if opcode == INSTRUMENTED_LINE {
        opcode_ptr = get_original_opcode_ptr(
            mon_ptr(monitoring, _PyCoMonitoringData_LINES), i
        );
        opcode = i32(opcode_ptr.view(1)[0]);
    }
    if opcode == INSTRUMENTED_INSTRUCTION {
        opcode_ptr = mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES)
            + i64(i);
        opcode = i32(opcode_ptr.view(1)[0]);
    }
    deinstrumented = de_instrument_of(opcode);
    if deinstrumented == 0 {
        return;
    }
    opcode_ptr.view(1)[0] = u8.wrap(deinstrumented);
    if opcode_caches(deinstrumented) != 0 {
        (instr + 1).view(1)[0] = warmup_counter();
    }
}

impl de_instrument_line(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
) {
    instr = bytecode + i64(i);
    opcode = i32(ptr[u8](instr).view(1)[0]);
    if opcode != INSTRUMENTED_LINE {
        return;
    }
    lines = mon_ptr(monitoring, _PyCoMonitoringData_LINES);
    original_opcode = get_original_opcode(lines, i);
    if original_opcode == INSTRUMENTED_INSTRUCTION {
        set_original_opcode(
            lines,
            i,
            i32(
                (
                    mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES)
                    + i64(i)
                ).view(
                    1
                )[0]
            )
        );
    }
    ptr[u8](instr).view(1)[0] = u8.wrap(original_opcode);
    if opcode_caches(original_opcode) != 0 {
        (instr + 1).view(1)[0] = warmup_counter();
    }
}

impl de_instrument_per_instruction(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
) {
    instr = bytecode + i64(i);
    opcode_ptr = ptr[u8](instr);
    opcode = i32(opcode_ptr.view(1)[0]);
    if opcode == INSTRUMENTED_LINE {
        opcode_ptr = get_original_opcode_ptr(
            mon_ptr(monitoring, _PyCoMonitoringData_LINES), i
        );
        opcode = i32(opcode_ptr.view(1)[0]);
    }
    if opcode != INSTRUMENTED_INSTRUCTION {
        return;
    }
    original_opcode = i32(
        (
            mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES) + i64(i)
        ).view(
            1
        )[0]
    );
    opcode_ptr.view(1)[0] = u8.wrap(original_opcode);
    if opcode_caches(original_opcode) != 0 {
        (instr + 1).view(1)[0] = warmup_counter();
    }
}

impl instrument(code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32) {
    instr = bytecode + i64(i);
    opcode_ptr = ptr[u8](instr);
    opcode = i32(opcode_ptr.view(1)[0]);
    if opcode == INSTRUMENTED_LINE {
        opcode_ptr = get_original_opcode_ptr(
            mon_ptr(monitoring, _PyCoMonitoringData_LINES), i
        );
        opcode = i32(opcode_ptr.view(1)[0]);
    }
    if opcode == INSTRUMENTED_INSTRUCTION {
        opcode_ptr = mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES)
            + i64(i);
        opcode = i32(opcode_ptr.view(1)[0]);
    }
    if not is_instrumented(opcode) {
        deopt = opcode_deopt(opcode);
        instrumented = instrumented_opcode(deopt);
        opcode_ptr.view(1)[0] = u8.wrap(instrumented);
        if opcode_caches(deopt) != 0 {
            (instr + 1).view(1)[0] = warmup_counter();
        }
    }
}

impl instrument_line(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
) {
    opcode_ptr = ptr[u8](bytecode + i64(i));
    opcode = i32(opcode_ptr.view(1)[0]);
    if opcode == INSTRUMENTED_LINE {
        return;
    }
    set_original_opcode(
        mon_ptr(monitoring, _PyCoMonitoringData_LINES), i, opcode_deopt(opcode)
    );
    opcode_ptr.view(1)[0] = u8.wrap(INSTRUMENTED_LINE);
}

impl instrument_per_instruction(
    code: ptr[PyObject], bytecode: ptr[u16], monitoring: ptr[u8], i: i32
) {
    instr = bytecode + i64(i);
    opcode_ptr = ptr[u8](instr);
    opcode = i32(opcode_ptr.view(1)[0]);
    if opcode == INSTRUMENTED_LINE {
        opcode_ptr = get_original_opcode_ptr(
            mon_ptr(monitoring, _PyCoMonitoringData_LINES), i
        );
        opcode = i32(opcode_ptr.view(1)[0]);
    }
    if opcode == INSTRUMENTED_INSTRUCTION {
        return;
    }
    per_instruction = mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES)
        + i64(i);
    if is_instrumented(opcode) {
        per_instruction.view(1)[0] = u8.wrap(opcode);
    } else {
        per_instruction.view(1)[0] = u8.wrap(opcode_deopt(opcode));
    }
    opcode_ptr.view(1)[0] = u8.wrap(INSTRUMENTED_INSTRUCTION);
}

impl remove_tools(code: ptr[PyObject], offset: i32, event: i32, tools: i32) {
    monitoring = code_monitoring(code);
    should_de_instrument = False;
    tools_array = mon_ptr(monitoring, _PyCoMonitoringData_TOOLS);
    if tools_array {
        slot = tools_array + i64(offset);
        slot.view(1)[0] = slot.view(1)[0] & ~u8.wrap(tools);
        should_de_instrument = slot.view(1)[0] == u8(0);
    } else {
        single_tool = (
            monitoring + _PyCoMonitoringData_ACTIVE_MONITORS + i64(event)
        ).view(
            1
        )[0];
        should_de_instrument = (single_tool & u8.wrap(tools)) == single_tool;
    }
    if should_de_instrument {
        de_instrument(code, code_units(code), monitoring, offset, event);
    }
}

impl remove_line_tools(code: ptr[PyObject], offset: i32, tools: i32) {
    monitoring = code_monitoring(code);
    should_de_instrument = False;
    line_tools = mon_ptr(monitoring, _PyCoMonitoringData_LINE_TOOLS);
    if line_tools {
        toolsptr = line_tools + i64(offset);
        toolsptr.view(1)[0] = toolsptr.view(1)[0] & ~u8.wrap(tools);
        should_de_instrument = toolsptr.view(1)[0] == u8(0);
    } else {
        single_tool = (
            monitoring
            + _PyCoMonitoringData_ACTIVE_MONITORS
            + i64(PY_MONITORING_EVENT_LINE)
        ).view(
            1
        )[0];
        should_de_instrument = (single_tool & u8.wrap(tools)) == single_tool;
    }
    if should_de_instrument {
        de_instrument_line(code, code_units(code), monitoring, offset);
    }
}

impl add_tools(code: ptr[PyObject], offset: i32, event: i32, tools: i32) {
    monitoring = code_monitoring(code);
    if monitoring {
        tools_array = mon_ptr(monitoring, _PyCoMonitoringData_TOOLS);
        if tools_array {
            slot = tools_array + i64(offset);
            slot.view(1)[0] = slot.view(1)[0] | u8.wrap(tools);
        }
    }
    instrument(code, code_units(code), monitoring, offset);
}

impl add_line_tools(code: ptr[PyObject], offset: i32, tools: i32) {
    monitoring = code_monitoring(code);
    line_tools = mon_ptr(monitoring, _PyCoMonitoringData_LINE_TOOLS);
    if line_tools {
        slot = line_tools + i64(offset);
        slot.view(1)[0] = slot.view(1)[0] | u8.wrap(tools);
    }
    instrument_line(code, code_units(code), monitoring, offset);
}

impl add_per_instruction_tools(code: ptr[PyObject], offset: i32, tools: i32) {
    monitoring = code_monitoring(code);
    per_instruction_tools = mon_ptr(
        monitoring, _PyCoMonitoringData_PER_INSTRUCTION_TOOLS
    );
    if per_instruction_tools {
        slot = per_instruction_tools + i64(offset);
        slot.view(1)[0] = slot.view(1)[0] | u8.wrap(tools);
    }
    instrument_per_instruction(code, code_units(code), monitoring, offset);
}

impl remove_per_instruction_tools(code: ptr[PyObject], offset: i32, tools: i32) {
    monitoring = code_monitoring(code);
    should_de_instrument = False;
    per_instruction_tools = mon_ptr(
        monitoring, _PyCoMonitoringData_PER_INSTRUCTION_TOOLS
    );
    if per_instruction_tools {
        toolsptr = per_instruction_tools + i64(offset);
        toolsptr.view(1)[0] = toolsptr.view(1)[0] & ~u8.wrap(tools);
        should_de_instrument = toolsptr.view(1)[0] == u8(0);
    } else {
        single_tool = (
            monitoring
            + _PyCoMonitoringData_ACTIVE_MONITORS
            + i64(PY_MONITORING_EVENT_INSTRUCTION)
        ).view(
            1
        )[0];
        should_de_instrument = (single_tool & u8.wrap(tools)) == single_tool;
    }
    if should_de_instrument {
        de_instrument_per_instruction(code, code_units(code), monitoring, offset);
    }
}

impl call_one_instrument(
    interp: ptr[u8],
    tstate: ptr[PyThreadState],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    tool: i32,
    event: i32
) -> i32 {
    instrument_obj = callable_slot(interp, tool, event).view(1)[0];
    if not instrument_obj {
        return 0;
    }
    what_event = tstate_i32(tstate, PyThreadState_WHAT_EVENT);
    tracing = tstate_i32(tstate, PyThreadState_TRACING);
    old_what = what_event.view(1)[0];
    what_event.view(1)[0] = event;
    tracing.view(1)[0] = tracing.view(1)[0] + 1;
    res = vectorcall_tstate(tstate, instrument_obj, args, nargsf, NULL);
    tracing.view(1)[0] = tracing.view(1)[0] - 1;
    what_event.view(1)[0] = old_what;
    if not res {
        return -1;
    }
    object_decref(res);
    return i32(1) if res == disable_object() else i32(0);
}

impl most_significant_bit(bits: u8) -> i32 {
    if bits > u8(15) {
        return i32((addressof(MOST_SIGNIFICANT_BITS) + i64(bits >> u8(4))).view(1)[0])
            + 4;
    }
    return i32((addressof(MOST_SIGNIFICANT_BITS) + i64(bits)).view(1)[0]);
}

impl global_version(interp: ptr[u8]) -> u32 {
    return u32.wrap(
        __atomic_load_i64(
            int(interp + PyInterpreterState_CEVAL_INSTRUMENTATION_VERSION), 0
        )
    );
}

impl set_version_raw(addr: int, version: u32) {
    old = __atomic_load_i64(addr, 0);
    while True {
        new_value = (old & i64(_PY_EVAL_EVENTS_MASK)) | i64(version);
        seen = __atomic_cas_i64(addr, old, new_value, 5);
        if seen == old {
            break;
        }
        old = seen;
    }
}

impl set_global_version(tstate: ptr[PyThreadState], version: u32) {
    interp = tstate_interp_of(tstate);
    set_version_raw(
        int(interp + PyInterpreterState_CEVAL_INSTRUMENTATION_VERSION), version
    );
    set_version_raw(int(ptr[u8](tstate) + PyThreadState_EVAL_BREAKER), version);
}

impl is_version_up_to_date(code: ptr[PyObject], interp: ptr[u8]) -> bool {
    return u64(global_version(interp)) == code_instrumentation_version(code);
}

impl get_tools_for_instruction(
    code: ptr[PyObject], interp: ptr[u8], i: i32, event_in: i32
) -> u8 {
    event = event_in;
    if event >= _PY_MONITORING_UNGROUPED_EVENTS {
        event = PY_MONITORING_EVENT_CALL;
    }
    if event < _PY_MONITORING_LOCAL_EVENTS {
        monitoring = code_monitoring(code);
        tools_array = mon_ptr(monitoring, _PyCoMonitoringData_TOOLS);
        if tools_array {
            return (tools_array + i64(i)).view(1)[0];
        }
        return (monitoring + _PyCoMonitoringData_ACTIVE_MONITORS + i64(event)).view(1)[
            0
        ];
    }
    return global_tools(interp, event);
}

impl call_instrumentation_vector(
    instr: ptr[u16],
    tstate: ptr[PyThreadState],
    event: i32,
    frame: ptr[u8],
    arg2: ptr[u16],
    nargs: i64,
    args: ptr[ptr[PyObject]]
) -> i32 {
    if tstate_i32(tstate, PyThreadState_TRACING).view(1)[0] != 0 {
        return 0;
    }
    code = iframe_code(frame);
    (args + 1).view(1)[0] = code;
    bytecode = int(iframe_bytecode(frame));
    offset = i32.wrap((int(instr) - bytecode) // 2);
    bytes_arg2 = i32.wrap((int(arg2) - bytecode) // 2) * 2;
    arg2_obj = PyLong_FromLong(i64(bytes_arg2));
    if not arg2_obj {
        return -1;
    }
    (args + 2).view(1)[0] = arg2_obj;
    interp = tstate_interp_of(tstate);
    tools = get_tools_for_instruction(code, interp, offset, event);
    nargsf = u64(nargs) | PY_VECTORCALL_ARGUMENTS_OFFSET;
    callargs = args + 1;
    err: i32 = 0;
    while tools != u8(0) {
        tool = most_significant_bit(tools);
        tools = tools ^ bit8(tool);
        res = call_one_instrument(interp, tstate, callargs, nargsf, tool, event);
        if res < 0 {
            err = -1;
            break;
        }
        if res > 0 {
            if event >= _PY_MONITORING_LOCAL_EVENTS {
                PyErr_Format(
                    PyExc_ValueError,
                    "Cannot disable %s events. Callback removed.",
                    event_name(event)
                );
                slot = callable_slot(interp, tool, event);
                old = slot.view(1)[0];
                slot.view(1)[0] = NULL;
                object_xdecref(old);
                err = -1;
                break;
            }
            _PyEval_StopTheWorld(interp);
            remove_tools(code, offset, event, 1 << tool);
            _PyEval_StartTheWorld(interp);
        }
    }
    object_decref(arg2_obj);
    return err;
}

impl call_instrumentation_vector_protected(
    tstate: ptr[PyThreadState],
    event: i32,
    frame: ptr[u8],
    instr: ptr[u16],
    nargs: i64,
    args: ptr[ptr[PyObject]]
) {
    exc = _PyErr_GetRaisedException(tstate);
    err = call_instrumentation_vector(instr, tstate, event, frame, instr, nargs, args);
    if err != 0 {
        object_xdecref(exc);
    } else {
        _PyErr_SetRaisedException(tstate, exc);
    }
}

impl get_frame_object(frame: ptr[u8]) -> ptr[PyObject] {
    res = iframe_ptr(frame, _PyInterpreterFrame_FRAME_OBJ);
    if res {
        return ptr[PyObject](res);
    }
    return _PyFrame_MakeAndSetFrameObject(frame);
}

impl call_line_tools(
    tstate: ptr[PyThreadState],
    interp: ptr[u8],
    code: ptr[PyObject],
    monitoring: ptr[u8],
    frame: ptr[u8],
    i: i32,
    line: i32
) -> i32 {
    tools: u8 = 0;
    line_tools = mon_ptr(monitoring, _PyCoMonitoringData_LINE_TOOLS);
    if line_tools {
        tools = (line_tools + i64(i)).view(1)[0];
    } else {
        tools = global_tools(interp, PY_MONITORING_EVENT_LINE)
            | (
                monitoring
                + _PyCoMonitoringData_LOCAL_MONITORS
                + i64(PY_MONITORING_EVENT_LINE)
            ).view(
                1
            )[0];
    }
    if (tools & bit8(PY_MONITORING_SYS_TRACE_ID)) != u8(0) {
        tstate_bytes = ptr[u8](tstate);
        if ptr[ptr[u8]](tstate_bytes + PyThreadState_C_TRACEFUNC).view(1)[0] {
            frame_obj = get_frame_object(frame);
            if not frame_obj {
                return -1;
            }
            if (ptr[u8](frame_obj) + PyFrameObject_TRACE_LINES).view(1)[0] != u8(0) {
                what_event = tstate_i32(tstate, PyThreadState_WHAT_EVENT);
                tracing = tstate_i32(tstate, PyThreadState_TRACING);
                old_what = what_event.view(1)[0];
                what_event.view(1)[0] = PY_MONITORING_EVENT_LINE;
                tracing.view(1)[0] = tracing.view(1)[0] + 1;
                object_incref(frame_obj);
                lineno = ptr[i32](ptr[u8](frame_obj) + PyFrameObject_LINENO);
                lineno.view(1)[0] = line;
                traceobj = ptr[ptr[PyObject]](
                    tstate_bytes + PyThreadState_C_TRACEOBJ
                ).view(
                    1
                )[0];
                err = ptr[MonitoringTraceCall](
                    tstate_bytes + PyThreadState_C_TRACEFUNC
                ).view(
                    1
                )[0].call(
                    traceobj, frame_obj, PyTrace_LINE, Py_None
                );
                lineno.view(1)[0] = 0;
                tracing.view(1)[0] = tracing.view(1)[0] - 1;
                what_event.view(1)[0] = old_what;
                object_decref(frame_obj);
                if err != 0 {
                    return -1;
                }
            }
        }
        tools = tools & u8(255 - (1 << PY_MONITORING_SYS_TRACE_ID));
    }
    if tools == u8(0) {
        return 0;
    }
    line_obj = PyLong_FromLong(i64(line));
    if not line_obj {
        return -1;
    }
    slots: own MonitoringSlots = MonitoringSlots();
    args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    (args + 1).view(1)[0] = code;
    (args + 2).view(1)[0] = line_obj;
    while True {
        tool = most_significant_bit(tools);
        tools = tools & ~bit8(tool);
        res = call_one_instrument(
            interp,
            tstate,
            args + 1,
            u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET,
            tool,
            PY_MONITORING_EVENT_LINE
        );
        if res < 0 {
            object_decref(line_obj);
            return -1;
        }
        if res > 0 {
            _PyEval_StopTheWorld(interp);
            remove_line_tools(code, i, 1 << tool);
            _PyEval_StartTheWorld(interp);
        }
        if tools == u8(0) {
            break;
        }
    }
    object_decref(line_obj);
    return 0;
}

impl initialize_tools(code: ptr[PyObject]) {
    monitoring = code_monitoring(code);
    tools = mon_ptr(monitoring, _PyCoMonitoringData_TOOLS);
    code_length = code_len(code);
    units = code_units(code);
    i: i32 = 0;
    while i < code_length {
        unit = (units + i64(i)).view(1)[0];
        opcode = unit_code(unit);
        if opcode == INSTRUMENTED_LINE {
            opcode = get_original_opcode(
                mon_ptr(monitoring, _PyCoMonitoringData_LINES), i
            );
        }
        if opcode == INSTRUMENTED_INSTRUCTION {
            opcode = i32(
                (
                    mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES)
                    + i64(i)
                ).view(
                    1
                )[0]
            );
        }
        instrumented = is_instrumented(opcode);
        if instrumented {
            opcode = de_instrument_of(opcode);
        }
        opcode = opcode_deopt(opcode);
        if opcode_has_event(opcode) {
            if instrumented {
                event: i32 = 0;
                if opcode == RESUME {
                    event = i32(1) if unit_arg(unit) != 0 else i32(0);
                } else {
                    event = event_for_opcode(opcode);
                }
                (tools + i64(i)).view(1)[0] = (
                    monitoring + _PyCoMonitoringData_ACTIVE_MONITORS + i64(event)
                ).view(
                    1
                )[0];
            } else {
                (tools + i64(i)).view(1)[0] = u8(0);
            }
        }
        i += opcode_caches(opcode);
        i += 1;
    }
}

impl initialize_lines(line_data: ptr[u8], code: ptr[PyObject], bytes_per_entry: i32) {
    line_data.view(1)[0] = u8.wrap(bytes_per_entry);
    code_length = code_len(code);
    firsttraceable = code_i32(code, PyCodeObject_FIRSTTRACEABLE);
    slots: own MonitoringSlots = MonitoringSlots();
    bounds = ptr[u8](jacpy_stack_address(&mut slots));
    _PyCode_InitAddressRange(code, bounds);
    current_line: i32 = -1;
    i: i32 = 0;
    while i < code_length {
        opcode = base_opcode(code, i);
        line = _PyCode_CheckLineNumber(i * 2, bounds);
        set_line_delta(line_data, i, compute_line_delta(code, line));
        length = _PyInstruction_GetLength(code, i);
        if i < firsttraceable {
            set_original_opcode(line_data, i, 0);
        } elif opcode == END_ASYNC_FOR
            or opcode == END_FOR
            or opcode == END_SEND
            or opcode == RESUME
            or opcode == POP_ITER {
            set_original_opcode(line_data, i, 0);
        } else {
            if line != current_line and line >= 0 {
                set_original_opcode(line_data, i, opcode);
            } else {
                set_original_opcode(line_data, i, 0);
            }
            current_line = line;
        }
        j: i32 = 1;
        while j < length {
            set_original_opcode(line_data, i + j, 0);
            set_line_delta(line_data, i + j, NO_LINE);
            j += 1;
        }
        i += length;
    }
    mark_jump_targets(line_data, code, code_length, firsttraceable);
    mark_exception_handlers(line_data, code);
}

impl mark_jump_targets(
    line_data: ptr[u8], code: ptr[PyObject], code_length: i32, firsttraceable: i32
) {
    i = firsttraceable;
    while i < code_length {
        inst = _Py_GetBaseCodeUnit(code, i);
        opcode = unit_code(inst);
        oparg: i32 = 0;
        while opcode == EXTENDED_ARG {
            oparg = i32.wrap((i64(oparg) << 8) | i64(unit_arg(inst)));
            i += 1;
            inst = _Py_GetBaseCodeUnit(code, i);
            opcode = unit_code(inst);
        }
        oparg = i32.wrap((i64(oparg) << 8) | i64(unit_arg(inst)));
        i += _PyInstruction_GetLength(code, i);
        target: i32 = -1;
        if opcode == POP_JUMP_IF_FALSE
            or opcode == POP_JUMP_IF_TRUE
            or opcode == POP_JUMP_IF_NONE
            or opcode == POP_JUMP_IF_NOT_NONE
            or opcode == JUMP_FORWARD {
            target = i + oparg;
        } elif opcode == FOR_ITER or opcode == SEND {
            target = i + oparg + 1;
        } elif opcode == JUMP_BACKWARD or opcode == JUMP_BACKWARD_NO_INTERRUPT {
            target = i - oparg;
        } else {
            continue;
        }
        if get_line_delta(line_data, target) != NO_LINE {
            target_opcode = base_opcode(code, target);
            if target_opcode != POP_ITER {
                set_original_opcode(line_data, target, target_opcode);
            }
        }
    }
}

impl mark_exception_handlers(line_data: ptr[u8], code: ptr[PyObject]) {
    exceptiontable = ptr[ptr[PyObject]](
        ptr[u8](code) + PyCodeObject_EXCEPTIONTABLE
    ).view(
        1
    )[0];
    start = ptr[u8](exceptiontable) + PyBytesObject_OB_SVAL;
    end = start + object_size(exceptiontable);
    scan = start;
    while int(scan) < int(end) {
        (after_start, start_offset) = parse_varint(scan);
        (after_size, size) = parse_varint(after_start);
        (after_handler, handler) = parse_varint(after_size);
        (after_depth, depth_and_lasti) = parse_varint(after_handler);
        scan = after_depth;
        handler_index = i32.wrap(handler);
        original_opcode = base_opcode(code, handler_index);
        if get_line_delta(line_data, handler_index) != NO_LINE
            and original_opcode != END_ASYNC_FOR {
            set_original_opcode(line_data, handler_index, original_opcode);
        }
    }
}

impl initialize_line_tools(code: ptr[PyObject], line_events: u8) {
    line_tools = mon_ptr(code_monitoring(code), _PyCoMonitoringData_LINE_TOOLS);
    code_length = code_len(code);
    i: i32 = 0;
    while i < code_length {
        (line_tools + i64(i)).view(1)[0] = line_events;
        i += 1;
    }
}

impl allocate_instrumentation_data(code: ptr[PyObject]) -> i32 {
    if not code_monitoring(code) {
        monitoring = ptr[u8](PyMem_Malloc(u64(_PyCoMonitoringData_SIZE)));
        if not monitoring {
            PyErr_NoMemory();
            return -1;
        }
        monitors_write(monitoring + _PyCoMonitoringData_LOCAL_MONITORS, u64(0), u64(0));
        monitors_write(
            monitoring + _PyCoMonitoringData_ACTIVE_MONITORS, u64(0), u64(0)
        );
        mon_set_ptr(monitoring, _PyCoMonitoringData_TOOLS, ptr[u8]());
        mon_set_ptr(monitoring, _PyCoMonitoringData_LINES, ptr[u8]());
        mon_set_ptr(monitoring, _PyCoMonitoringData_LINE_TOOLS, ptr[u8]());
        mon_set_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES, ptr[u8]());
        mon_set_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_TOOLS, ptr[u8]());
        __atomic_store_i64(
            int(ptr[u8](code) + PyCodeObject_MONITORING), i64(int(monitoring)), 3
        );
    }
    return 0;
}

impl line_bytes_per_entry(code: ptr[PyObject], code_length: i32) -> i32 {
    firstlineno = code_i32(code, PyCodeObject_FIRSTLINENO);
    slots: own MonitoringSlots = MonitoringSlots();
    bounds = ptr[u8](jacpy_stack_address(&mut slots));
    _PyCode_InitAddressRange(code, bounds);
    max_line = firstlineno + 1;
    _PyCode_InitAddressRange(code, bounds);
    i = code_i32(code, PyCodeObject_FIRSTTRACEABLE);
    while i < code_length {
        line = _PyCode_CheckLineNumber(i * 2, bounds);
        if line > max_line {
            max_line = line;
        }
        i += _PyInstruction_GetLength(code, i);
    }
    max_delta = max_line - firstlineno;
    if max_delta < 256 + NO_LINE {
        return 2;
    }
    if max_delta < (1 << 16) + NO_LINE {
        return 3;
    }
    if max_delta < (1 << 24) + NO_LINE {
        return 4;
    }
    return 5;
}

impl update_instrumentation_data(code: ptr[PyObject], interp: ptr[u8]) -> i32 {
    code_length = code_len(code);
    if allocate_instrumentation_data(code) != 0 {
        return -1;
    }
    monitoring = code_monitoring(code);
    local_monitors = monitoring + _PyCoMonitoringData_LOCAL_MONITORS;
    i: i32 = 0;
    while i < PY_MONITORING_TOOL_IDS {
        code_version = ptr[u64](
            monitoring + _PyCoMonitoringData_TOOL_VERSIONS + i64(i) * 8
        ).view(
            1
        )[0];
        if code_version != interp_tool_version(interp, i).view(1)[0] {
            j: i64 = 0;
            while j < i64(_PY_MONITORING_LOCAL_EVENTS) {
                (local_monitors + j).view(1)[0] = (local_monitors + j).view(1)[0]
                    & ~bit8(i);
                j += 1;
            }
        }
        i += 1;
    }
    (global_lo, global_hi) = monitors_read(interp + PyInterpreterState_MONITORS);
    (local_lo, local_hi) = monitors_read(local_monitors);
    all_lo = global_lo | local_lo;
    all_hi = global_hi | local_hi;
    multitools = multiple_tools(all_lo, all_hi);
    if not mon_ptr(monitoring, _PyCoMonitoringData_TOOLS) and multitools {
        tools = ptr[u8](PyMem_Malloc(u64(code_length)));
        mon_set_ptr(monitoring, _PyCoMonitoringData_TOOLS, tools);
        if not tools {
            PyErr_NoMemory();
            return -1;
        }
        initialize_tools(code);
    }
    line_events = monitors_tool(all_lo, all_hi, PY_MONITORING_EVENT_LINE);
    if line_events != u8(0) {
        if not mon_ptr(monitoring, _PyCoMonitoringData_LINES) {
            bytes_per_entry = line_bytes_per_entry(code, code_length);
            lines = ptr[u8](PyMem_Malloc(u64(1 + code_length * bytes_per_entry)));
            if not lines {
                PyErr_NoMemory();
                return -1;
            }
            initialize_lines(lines, code, bytes_per_entry);
            __atomic_store_i64(
                int(monitoring + _PyCoMonitoringData_LINES), i64(int(lines)), 3
            );
        }
        if multitools and not mon_ptr(monitoring, _PyCoMonitoringData_LINE_TOOLS) {
            line_tools = ptr[u8](PyMem_Malloc(u64(code_length)));
            mon_set_ptr(monitoring, _PyCoMonitoringData_LINE_TOOLS, line_tools);
            if not line_tools {
                PyErr_NoMemory();
                return -1;
            }
            initialize_line_tools(code, line_events);
        }
    }
    if monitors_tool(all_lo, all_hi, PY_MONITORING_EVENT_INSTRUCTION) != u8(0) {
        if not mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES) {
            opcodes = ptr[u8](PyMem_Malloc(u64(code_length) * LINE_DATA_ENTRY_SIZE));
            mon_set_ptr(
                monitoring, _PyCoMonitoringData_PER_INSTRUCTION_OPCODES, opcodes
            );
            if not opcodes {
                PyErr_NoMemory();
                return -1;
            }
            units = code_units(code);
            k: i32 = 0;
            while k < code_length {
                (opcodes + i64(k)).view(1)[0] = u8.wrap(
                    opcode_deopt(unit_code((units + i64(k)).view(1)[0]))
                );
                k += 1;
            }
        }
        if multitools
            and not mon_ptr(monitoring, _PyCoMonitoringData_PER_INSTRUCTION_TOOLS) {
            per_tools = ptr[u8](PyMem_Malloc(u64(code_length)));
            mon_set_ptr(
                monitoring, _PyCoMonitoringData_PER_INSTRUCTION_TOOLS, per_tools
            );
            if not per_tools {
                PyErr_NoMemory();
                return -1;
            }
            m: i32 = 0;
            while m < code_length {
                (per_tools + i64(m)).view(1)[0] = u8(0);
                m += 1;
            }
        }
    }
    return 0;
}

impl apply_event_changes(
    code: ptr[PyObject],
    code_length: i32,
    new_lo: u64,
    new_hi: u64,
    removed_lo: u64,
    removed_hi: u64
) {
    firsttraceable = code_i32(code, PyCodeObject_FIRSTTRACEABLE);
    i = firsttraceable;
    while i < code_length {
        inst = _Py_GetBaseCodeUnit(code, i);
        opcode = unit_code(inst);
        if opcode_has_event(opcode) {
            event: i32 = 0;
            if opcode == RESUME {
                event = i32(1) if unit_arg(inst) > 0 else i32(0);
            } else {
                event = event_for_opcode(opcode);
            }
            removed_tools = monitors_tool(removed_lo, removed_hi, event);
            if removed_tools != u8(0) {
                remove_tools(code, i, event, i32(removed_tools));
            }
            new_tools = monitors_tool(new_lo, new_hi, event);
            if new_tools != u8(0) {
                add_tools(code, i, event, i32(new_tools));
            }
        }
        i += _PyInstruction_GetLength(code, i);
    }
    monitoring = code_monitoring(code);
    removed_line_tools = i32(
        monitors_tool(removed_lo, removed_hi, PY_MONITORING_EVENT_LINE)
    );
    removed_per_instruction_tools = i32(
        monitors_tool(removed_lo, removed_hi, PY_MONITORING_EVENT_INSTRUCTION)
    );
    if removed_line_tools != 0 {
        line_data = mon_ptr(monitoring, _PyCoMonitoringData_LINES);
        i = firsttraceable;
        while i < code_length {
            if get_original_opcode(line_data, i) != 0 {
                remove_line_tools(code, i, removed_line_tools);
            }
            i += _PyInstruction_GetLength(code, i);
        }
    }
    if removed_per_instruction_tools != 0 {
        i = firsttraceable;
        while i < code_length {
            opcode = base_opcode(code, i);
            if opcode != RESUME and opcode != END_FOR {
                remove_per_instruction_tools(code, i, removed_per_instruction_tools);
            }
            i += _PyInstruction_GetLength(code, i);
        }
    }
    new_line_tools = i32(monitors_tool(new_lo, new_hi, PY_MONITORING_EVENT_LINE));
    new_per_instruction_tools = i32(
        monitors_tool(new_lo, new_hi, PY_MONITORING_EVENT_INSTRUCTION)
    );
    if new_line_tools != 0 {
        line_data = mon_ptr(monitoring, _PyCoMonitoringData_LINES);
        i = firsttraceable;
        while i < code_length {
            if get_original_opcode(line_data, i) != 0 {
                add_line_tools(code, i, new_line_tools);
            }
            i += _PyInstruction_GetLength(code, i);
        }
    }
    if new_per_instruction_tools != 0 {
        i = firsttraceable;
        while i < code_length {
            opcode = base_opcode(code, i);
            if opcode != RESUME and opcode != END_FOR {
                add_per_instruction_tools(code, i, new_per_instruction_tools);
            }
            i += _PyInstruction_GetLength(code, i);
        }
    }
}

impl force_instrument_lock_held(code: ptr[PyObject], interp: ptr[u8]) -> i32 {
    code_length = code_len(code);
    if (code_i32(code, PyCodeObject_FLAGS) & CO_NO_MONITORING_EVENTS) != 0 {
        return 0;
    }
    if update_instrumentation_data(code, interp) != 0 {
        return -1;
    }
    monitoring = code_monitoring(code);
    (global_lo, global_hi) = monitors_read(interp + PyInterpreterState_MONITORS);
    (local_lo, local_hi) = monitors_read(
        monitoring + _PyCoMonitoringData_LOCAL_MONITORS
    );
    active_lo = global_lo | local_lo;
    active_hi = global_hi | local_hi;
    (current_lo, current_hi) = monitors_read(
        monitoring + _PyCoMonitoringData_ACTIVE_MONITORS
    );
    new_lo: u64 = 0;
    new_hi: u64 = 0;
    removed_lo: u64 = 0;
    removed_hi: u64 = 0;
    restarted = ptr[u64](interp + PyInterpreterState_LAST_RESTART_VERSION).view(1)[0]
        > code_instrumentation_version(code);
    if restarted {
        removed_lo = current_lo;
        removed_hi = current_hi;
        new_lo = active_lo;
        new_hi = active_hi;
    } else {
        removed_lo = current_lo & ~active_lo;
        removed_hi = current_hi & ~active_hi;
        new_lo = active_lo & ~current_lo;
        new_hi = active_hi & ~current_hi;
    }
    monitors_write(
        monitoring + _PyCoMonitoringData_ACTIVE_MONITORS, active_lo, active_hi
    );
    if not (
        monitors_are_empty(new_lo, new_hi)
        and monitors_are_empty(removed_lo, removed_hi)
    ) {
        apply_event_changes(code, code_length, new_lo, new_hi, removed_lo, removed_hi);
    }
    ptr[u64](ptr[u8](code) + PyCodeObject_INSTRUMENTATION_VERSION).view(1)[0] = u64(
        global_version(interp)
    );
    return 0;
}

impl instrument_lock_held(code: ptr[PyObject], interp: ptr[u8]) -> i32 {
    if is_version_up_to_date(code, interp) {
        return 0;
    }
    return force_instrument_lock_held(code, interp);
}

impl instrument_all_executing_code_objects(interp: ptr[u8]) -> i32 {
    runtime = ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
    head_lock(runtime);
    err: i32 = 0;
    ts = ptr[ptr[u8]](interp + PyInterpreterState_THREADS_HEAD).view(1)[0];
    while ts and err == 0 {
        frame = tstate_current_frame(ptr(ts));
        while frame {
            if i32((frame + _PyInterpreterFrame_OWNER).view(1)[0])
                < FRAME_OWNED_BY_INTERPRETER {
                err = instrument_lock_held(iframe_code(frame), interp);
                if err != 0 {
                    break;
                }
            }
            frame = iframe_ptr(frame, _PyInterpreterFrame_PREVIOUS);
        }
        ts = ptr[ptr[u8]](ts + PyThreadState_NEXT).view(1)[0];
    }
    head_unlock(runtime);
    return err;
}

impl check_tool(interp: ptr[u8], tool_id: i32) -> i32 {
    if tool_id < PY_MONITORING_SYS_PROFILE_ID
        and not tool_name_slot(interp, tool_id).view(1)[0] {
        PyErr_Format(PyExc_ValueError, "tool %d is not in use", tool_id);
        return -1;
    }
    return 0;
}

impl check_valid_tool(tool_id: i32) -> i32 {
    if tool_id < 0 or tool_id >= PY_MONITORING_SYS_PROFILE_ID {
        PyErr_Format(
            PyExc_ValueError, "invalid tool %d (must be between 0 and 5)", tool_id
        );
        return -1;
    }
    return 0;
}

impl code_check(op: ptr[PyObject]) -> bool {
    return ptr[PyObject](object_type(op)) == addressof(PyCode_Type);
}

impl monitoring_use_tool_id_impl(
    module: ptr[PyObject], tool_id: i32, name: ptr[PyObject]
) -> ptr[PyObject] {
    if check_valid_tool(tool_id) != 0 {
        return NULL;
    }
    if not unicode_check(name) {
        PyErr_SetString(PyExc_ValueError, "tool name must be a str");
        return NULL;
    }
    interp = current_interp();
    slot = tool_name_slot(interp, tool_id);
    if slot.view(1)[0] {
        PyErr_Format(PyExc_ValueError, "tool %d is already in use", tool_id);
        return NULL;
    }
    slot.view(1)[0] = object_new_ref(name);
    return object_new_ref(Py_None);
}

impl monitoring_clear_tool_id_impl(
    module: ptr[PyObject], tool_id: i32
) -> ptr[PyObject] {
    if check_valid_tool(tool_id) != 0 {
        return NULL;
    }
    interp = current_interp();
    if tool_name_slot(interp, tool_id).view(1)[0] {
        if _PyMonitoring_ClearToolId(tool_id) < 0 {
            return NULL;
        }
    }
    return object_new_ref(Py_None);
}

impl monitoring_free_tool_id_impl(
    module: ptr[PyObject], tool_id: i32
) -> ptr[PyObject] {
    if check_valid_tool(tool_id) != 0 {
        return NULL;
    }
    interp = current_interp();
    if tool_name_slot(interp, tool_id).view(1)[0] {
        if _PyMonitoring_ClearToolId(tool_id) < 0 {
            return NULL;
        }
    }
    slot = tool_name_slot(interp, tool_id);
    old = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(old);
    return object_new_ref(Py_None);
}

impl monitoring_get_tool_impl(module: ptr[PyObject], tool_id: i32) -> ptr[PyObject] {
    if check_valid_tool(tool_id) != 0 {
        return NULL;
    }
    name = tool_name_slot(current_interp(), tool_id).view(1)[0];
    if not name {
        return object_new_ref(Py_None);
    }
    return object_new_ref(name);
}

impl monitoring_register_callback_impl(
    module: ptr[PyObject], tool_id: i32, event: i32, func_in: ptr[PyObject]
) -> ptr[PyObject] {
    if check_valid_tool(tool_id) != 0 {
        return NULL;
    }
    if popcount32(u32.wrap(event)) != 1 {
        PyErr_SetString(
            PyExc_ValueError, "The callback can only be set for one event at a time"
        );
        return NULL;
    }
    event_id = bit_length(u64.wrap(i64(event))) - 1;
    if event_id < 0 or event_id >= _PY_MONITORING_EVENTS {
        PyErr_Format(PyExc_ValueError, "invalid event %d", event);
        return NULL;
    }
    if PySys_Audit("sys.monitoring.register_callback", "O", func_in) < 0 {
        return NULL;
    }
    func = func_in;
    if func == Py_None {
        func = NULL;
    }
    func = _PyMonitoring_RegisterCallback(tool_id, event_id, func);
    if not func {
        return object_new_ref(Py_None);
    }
    return func;
}

impl monitoring_get_events_impl(module: ptr[PyObject], tool_id: i32) -> i32 {
    if check_valid_tool(tool_id) != 0 {
        return -1;
    }
    event_set = get_events(current_interp() + PyInterpreterState_MONITORS, tool_id);
    return i32.wrap(event_set);
}

impl normalize_event_set(event_set_in: i32) -> i32 {
    event_set = event_set_in & ~C_RETURN_EVENTS;
    if (event_set & (1 << PY_MONITORING_EVENT_BRANCH)) != 0 {
        event_set = event_set & ~(1 << PY_MONITORING_EVENT_BRANCH);
        event_set = event_set
            | (1 << PY_MONITORING_EVENT_BRANCH_RIGHT)
            | (1 << PY_MONITORING_EVENT_BRANCH_LEFT);
    }
    return event_set;
}

impl monitoring_set_events_impl(
    module: ptr[PyObject], tool_id: i32, event_set_in: i32
) -> ptr[PyObject] {
    if check_valid_tool(tool_id) != 0 {
        return NULL;
    }
    if event_set_in < 0 or event_set_in >= (1 << _PY_MONITORING_EVENTS) {
        PyErr_Format(PyExc_ValueError, "invalid event set 0x%x", event_set_in);
        return NULL;
    }
    if (event_set_in & C_RETURN_EVENTS) != 0
        and (event_set_in & C_CALL_EVENTS) != C_CALL_EVENTS {
        PyErr_Format(
            PyExc_ValueError, "cannot set C_RETURN or C_RAISE events independently"
        );
        return NULL;
    }
    event_set = normalize_event_set(event_set_in);
    interp = current_interp();
    _PyEval_StopTheWorld(interp);
    err = _PyMonitoring_SetEvents(tool_id, u32.wrap(event_set));
    _PyEval_StartTheWorld(interp);
    if err != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl monitoring_get_local_events_impl(
    module: ptr[PyObject], tool_id: i32, code: ptr[PyObject]
) -> i32 {
    if not code_check(code) {
        PyErr_Format(PyExc_TypeError, "code must be a code object");
        return -1;
    }
    if check_valid_tool(tool_id) != 0 {
        return -1;
    }
    event_set: u32 = 0;
    data = code_monitoring(code);
    if data {
        event_set = get_local_events(
            data + _PyCoMonitoringData_LOCAL_MONITORS, tool_id
        );
    }
    return i32.wrap(event_set);
}

impl monitoring_set_local_events_impl(
    module: ptr[PyObject], tool_id: i32, code: ptr[PyObject], event_set_in: i32
) -> ptr[PyObject] {
    if not code_check(code) {
        PyErr_Format(PyExc_TypeError, "code must be a code object");
        return NULL;
    }
    if check_valid_tool(tool_id) != 0 {
        return NULL;
    }
    if (event_set_in & C_RETURN_EVENTS) != 0
        and (event_set_in & C_CALL_EVENTS) != C_CALL_EVENTS {
        PyErr_Format(
            PyExc_ValueError, "cannot set C_RETURN or C_RAISE events independently"
        );
        return NULL;
    }
    event_set = normalize_event_set(event_set_in);
    if event_set < 0 or event_set >= (1 << _PY_MONITORING_LOCAL_EVENTS) {
        PyErr_Format(PyExc_ValueError, "invalid local event set 0x%x", event_set);
        return NULL;
    }
    interp = current_interp();
    _PyEval_StopTheWorld(interp);
    err = _PyMonitoring_SetLocalEvents(code, tool_id, u32.wrap(event_set));
    _PyEval_StartTheWorld(interp);
    if err != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl monitoring_restart_events_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    tstate = current_tstate();
    interp = tstate_interp_of(tstate);
    _PyEval_StopTheWorld(interp);
    restart_version = wrapping_add(
        global_version(interp), MONITORING_VERSION_INCREMENT
    );
    new_version = wrapping_add(restart_version, MONITORING_VERSION_INCREMENT);
    if new_version <= MONITORING_VERSION_INCREMENT {
        _PyEval_StartTheWorld(interp);
        PyErr_Format(PyExc_OverflowError, "events set too many times");
        return NULL;
    }
    ptr[u64](interp + PyInterpreterState_LAST_RESTART_VERSION).view(1)[0] = u64(
        restart_version
    );
    set_global_version(tstate, new_version);
    res = instrument_all_executing_code_objects(interp);
    _PyEval_StartTheWorld(interp);
    if res != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl add_power2_constant(obj_: ptr[PyObject], name: ptr[u8], i: i32) -> i32 {
    val = PyLong_FromLong(i64(1 << i));
    if not val {
        return -1;
    }
    err = PyObject_SetAttrString(obj_, name, val);
    object_decref(val);
    return err;
}

impl monitoring__all_events_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = current_interp();
    res = PyDict_New();
    if not res {
        return NULL;
    }
    e: i32 = 0;
    while e < _PY_MONITORING_UNGROUPED_EVENTS {
        tools = global_tools(interp, e);
        if tools != u8(0) {
            tools_obj = PyLong_FromLong(i64(tools));
            err = PyDict_SetItemString(res, event_name(e), tools_obj);
            object_decref(tools_obj);
            if err < 0 {
                object_decref(res);
                return NULL;
            }
        }
        e += 1;
    }
    return res;
}

impl arg_int(arg: ptr[PyObject]) -> tuple[bool, i32] {
    value = PyLong_AsInt(arg);
    if value == -1 and PyErr_Occurred() {
        return (False, value);
    }
    return (True, value);
}

impl monitoring_use_tool_id(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not (
        nargs == 2 or _PyArg_CheckPositional(ptr[u8]("use_tool_id"), nargs, 2, 2) != 0
    ) {
        return NULL;
    }
    (ok, tool_id) = arg_int(args.view(2)[0]);
    if not ok {
        return NULL;
    }
    return monitoring_use_tool_id_impl(module, tool_id, args.view(2)[1]);
}

impl monitoring_clear_tool_id(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    (ok, tool_id) = arg_int(arg);
    if not ok {
        return NULL;
    }
    return monitoring_clear_tool_id_impl(module, tool_id);
}

impl monitoring_free_tool_id(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    (ok, tool_id) = arg_int(arg);
    if not ok {
        return NULL;
    }
    return monitoring_free_tool_id_impl(module, tool_id);
}

impl monitoring_get_tool(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    (ok, tool_id) = arg_int(arg);
    if not ok {
        return NULL;
    }
    return monitoring_get_tool_impl(module, tool_id);
}

impl monitoring_register_callback(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not (
        nargs == 3
        or _PyArg_CheckPositional(ptr[u8]("register_callback"), nargs, 3, 3) != 0
    ) {
        return NULL;
    }
    (ok, tool_id) = arg_int(args.view(3)[0]);
    if not ok {
        return NULL;
    }
    (ok_event, event) = arg_int(args.view(3)[1]);
    if not ok_event {
        return NULL;
    }
    return monitoring_register_callback_impl(module, tool_id, event, args.view(3)[2]);
}

impl monitoring_get_events(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    (ok, tool_id) = arg_int(arg);
    if not ok {
        return NULL;
    }
    return_value = monitoring_get_events_impl(module, tool_id);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromLong(i64(return_value));
}

impl monitoring_set_events(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not (
        nargs == 2 or _PyArg_CheckPositional(ptr[u8]("set_events"), nargs, 2, 2) != 0
    ) {
        return NULL;
    }
    (ok, tool_id) = arg_int(args.view(2)[0]);
    if not ok {
        return NULL;
    }
    (ok_set, event_set) = arg_int(args.view(2)[1]);
    if not ok_set {
        return NULL;
    }
    return monitoring_set_events_impl(module, tool_id, event_set);
}

impl monitoring_get_local_events(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not (
        nargs == 2
        or _PyArg_CheckPositional(ptr[u8]("get_local_events"), nargs, 2, 2) != 0
    ) {
        return NULL;
    }
    (ok, tool_id) = arg_int(args.view(2)[0]);
    if not ok {
        return NULL;
    }
    return_value = monitoring_get_local_events_impl(module, tool_id, args.view(2)[1]);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromLong(i64(return_value));
}

impl monitoring_set_local_events(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not (
        nargs == 3
        or _PyArg_CheckPositional(ptr[u8]("set_local_events"), nargs, 3, 3) != 0
    ) {
        return NULL;
    }
    (ok, tool_id) = arg_int(args.view(3)[0]);
    if not ok {
        return NULL;
    }
    (ok_set, event_set) = arg_int(args.view(3)[2]);
    if not ok_set {
        return NULL;
    }
    return monitoring_set_local_events_impl(
        module, tool_id, args.view(3)[1], event_set
    );
}

impl monitoring_restart_events(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return monitoring_restart_events_impl(module);
}

impl monitoring__all_events(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return monitoring__all_events_impl(module);
}

impl set_int_attr(obj_: ptr[PyObject], name: ptr[u8], value: i32) -> i32 {
    val = PyLong_FromLong(i64(value));
    err = PyObject_SetAttrString(obj_, name, val);
    object_decref(val);
    return err;
}

impl capi_call_instrumentation(
    state: ptr[u8],
    codelike: ptr[PyObject],
    offset: i32,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    event: i32
) -> i32 {
    tstate = current_tstate();
    interp = tstate_interp_of(tstate);
    tools = state.view(1)[0];
    (args + 1).view(1)[0] = codelike;
    if offset < 0 {
        PyErr_SetString(PyExc_ValueError, "offset must be non-negative");
        return -1;
    }
    if event != PY_MONITORING_EVENT_LINE {
        offset_obj = PyLong_FromLong(i64(offset));
        if not offset_obj {
            return -1;
        }
        (args + 2).view(1)[0] = offset_obj;
    }
    nargsf = u64(nargs) | PY_VECTORCALL_ARGUMENTS_OFFSET;
    callargs = args + 1;
    err: i32 = 0;
    while tools != u8(0) {
        tool = most_significant_bit(tools);
        tools = tools ^ bit8(tool);
        res = call_one_instrument(interp, tstate, callargs, nargsf, tool, event);
        if res < 0 {
            err = -1;
            break;
        }
        if res > 0 {
            if event >= _PY_MONITORING_LOCAL_EVENTS {
                PyErr_Format(
                    PyExc_ValueError,
                    "Cannot disable %s events. Callback removed.",
                    event_name(event)
                );
                slot = callable_slot(interp, tool, event);
                old = slot.view(1)[0];
                slot.view(1)[0] = NULL;
                object_xdecref(old);
                err = -1;
                break;
            }
            state.view(1)[0] = state.view(1)[0] & ~bit8(tool);
        }
    }
    return err;
}

impl capi_fire(
    state: ptr[u8],
    codelike: ptr[PyObject],
    offset: i32,
    arg0: ptr[PyObject],
    arg1: ptr[PyObject],
    nargs: i64,
    event: i32
) -> i32 {
    slots: own MonitoringSlots = MonitoringSlots();
    args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    (args + 3).view(1)[0] = arg0;
    (args + 4).view(1)[0] = arg1;
    return capi_call_instrumentation(state, codelike, offset, args, nargs, event);
}

impl exception_event_setup(event: i32) -> tuple[i32, ptr[PyObject]] {
    exc = PyErr_GetRaisedException();
    if not exc {
        PyErr_Format(PyExc_ValueError, "Firing event %d with no exception set", event);
        return (i32(-1), exc);
    }
    return (i32(0), exc);
}

impl exception_event_teardown(err: i32, exc: ptr[PyObject]) -> i32 {
    if err == 0 {
        PyErr_SetRaisedException(exc);
    } else {
        object_xdecref(exc);
    }
    return err;
}

impl capi_fire_exception(
    state: ptr[u8], codelike: ptr[PyObject], offset: i32, event: i32
) -> i32 {
    (status, exc) = exception_event_setup(event);
    if status < 0 {
        return -1;
    }
    err = capi_fire(state, codelike, offset, exc, NULL, 3, event);
    return exception_event_teardown(err, exc);
}

impl dealloc_branch_handler(op: ptr[PyObject]) {
    self_ = ptr[LegacyBranchEventHandler](op);
    handler = self_.view(1)[0].handler;
    self_.view(1)[0].handler = NULL;
    object_xdecref(handler);
    PyObject_Free(op);
}

impl trunc_half(x: i32) -> i32 {
    if x < 0 {
        return i32.wrap(-((-i64(x)) // 2));
    }
    return x // 2;
}

impl branch_handler_vectorcall(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[LegacyBranchEventHandler](op);
    code = args.view(2)[0];
    src_offset = i32.wrap(PyLong_AsLong(args.view(2)[1]));
    if PyErr_Occurred() {
        return NULL;
    }
    instr_opcode = unit_code(
        (code_units(code) + i64(trunc_half(src_offset))).view(1)[0]
    );
    if not is_instrumented(instr_opcode) {
        return disable_object();
    }
    res = PyObject_Vectorcall(self_.view(1)[0].handler, args, nargsf, kwnames);
    if res == disable_object() {
        offset: i32 = 0;
        other_event: i32 = 0;
        if instr_opcode == FOR_ITER {
            if self_.view(1)[0].right {
                offset = trunc_half(src_offset);
                other_event = PY_MONITORING_EVENT_BRANCH_LEFT;
            } else {
                return res;
            }
        } elif instr_opcode == POP_JUMP_IF_FALSE
            or instr_opcode == POP_JUMP_IF_TRUE
            or instr_opcode == POP_JUMP_IF_NONE
            or instr_opcode == POP_JUMP_IF_NOT_NONE {
            if self_.view(1)[0].right {
                offset = trunc_half(src_offset) + 2;
                other_event = PY_MONITORING_EVENT_BRANCH_LEFT;
            } else {
                offset = trunc_half(src_offset);
                other_event = PY_MONITORING_EVENT_BRANCH_RIGHT;
            }
        } else {
            return res;
        }
        interp = current_interp();
        _PyEval_StopTheWorld(interp);
        remove_tools(code, offset, other_event, 1 << self_.view(1)[0].tool_id);
        _PyEval_StartTheWorld(interp);
    }
    return res;
}

impl make_branch_handler(
    tool_id: i32, handler: ptr[PyObject], right: bool
) -> ptr[PyObject] {
    callback = _PyObject_New(
        ptr[PyObject](addressof(_PyLegacyBranchEventHandler_Type))
    );
    if not callback {
        return NULL;
    }
    self_ = ptr[LegacyBranchEventHandler](callback);
    self_.view(1)[0].vectorcall = branch_handler_vectorcall;
    self_.view(1)[0].handler = object_new_ref(handler);
    self_.view(1)[0].right = right;
    self_.view(1)[0].tool_id = tool_id;
    return callback;
}

impl int_triple(a: i32, b: i32, c: i32) -> ptr[PyObject] {
    obja = PyLong_FromLong(i64(a));
    if not obja {
        return NULL;
    }
    objb = PyLong_FromLong(i64(b));
    if not objb {
        object_decref(obja);
        return NULL;
    }
    objc = PyLong_FromLong(i64(c));
    if not objc {
        object_decref(obja);
        object_decref(objb);
        return NULL;
    }
    slots: own MonitoringSlots = MonitoringSlots();
    array = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    array.view(3)[0] = obja;
    array.view(3)[1] = objb;
    array.view(3)[2] = objc;
    return _PyTuple_FromArraySteal(array, 3);
}

impl branchesiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    bi = ptr[BranchesIterator](op);
    code = bi.view(1)[0].bi_code;
    offset = bi.view(1)[0].bi_offset;
    oparg: i32 = 0;
    while i64(offset) < object_size(code) {
        inst = _Py_GetBaseCodeUnit(code, offset);
        opcode = unit_code(inst);
        next_offset = offset + 1 + opcode_caches(opcode);
        if opcode == EXTENDED_ARG {
            oparg = i32.wrap((i64(oparg) << 8) | i64(unit_arg(inst)));
        } elif opcode == FOR_ITER {
            oparg = i32.wrap((i64(oparg) << 8) | i64(unit_arg(inst)));
            bi.view(1)[0].bi_offset = next_offset;
            target = next_offset + oparg + 2;
            return int_triple(offset * 2, next_offset * 2, target * 2);
        } elif opcode == POP_JUMP_IF_FALSE
            or opcode == POP_JUMP_IF_TRUE
            or opcode == POP_JUMP_IF_NONE
            or opcode == POP_JUMP_IF_NOT_NONE {
            oparg = i32.wrap((i64(oparg) << 8) | i64(unit_arg(inst)));
            not_taken = next_offset + 1;
            bi.view(1)[0].bi_offset = not_taken;
            return int_triple(offset * 2, not_taken * 2, (next_offset + oparg) * 2);
        } elif opcode == END_ASYNC_FOR {
            oparg = i32.wrap((i64(oparg) << 8) | i64(unit_arg(inst)));
            src_offset = next_offset - oparg;
            bi.view(1)[0].bi_offset = next_offset;
            not_taken = src_offset + 2;
            return int_triple(src_offset * 2, not_taken * 2, next_offset * 2);
        } else {
            oparg = 0;
        }
        offset = next_offset;
    }
    return NULL;
}

impl branchesiter_dealloc(op: ptr[PyObject]) {
    object_decref(ptr[BranchesIterator](op).view(1)[0].bi_code);
    PyObject_Free(op);
}
