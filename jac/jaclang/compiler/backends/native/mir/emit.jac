glob RAISE_BUILTIN_SYMBOL: str = "__jac_rt_raise_builtin",
     RETAIN_SYMBOL: str = "__jac_rt_retain",
     BUILTIN_SETJMP_SYMBOL: str = "llvm.eh.sjlj.setjmp",
     EXC_FRAME_BYTES: int = 296,
     RELEASE_SYMBOL: str = "__jac_rt_release",
     RELEASE_ACYCLIC_SYMBOL: str = "__jac_rt_release_acyclic",
     DROP_SYMBOL: str = "__jac_rt_drop",
     PIN_SHARE_SYMBOL: str = "__jac_rt_pin_share",
     DROP_TEXT_SYMBOL: str = "__jac_rt_drop_text",
     ANY_DROP_SYMBOL: str = "__jac_rt_any_drop",
     ANY_RETAIN_SYMBOL: str = "__jac_rt_any_retain",
     ANY_RELEASE_SYMBOL: str = "__jac_rt_any_release",
     ANY_OPS: list[MirOp] = [
         MirOp.ANY_BOX,
         MirOp.ANY_MAKE,
         MirOp.ANY_TAG,
         MirOp.ANY_PAYLOAD
     ],
     C_OPS: list[MirOp] = [
         MirOp.PTR_CAST,
         MirOp.PTR_INT,
         MirOp.PTR_NULL,
         MirOp.PTR_OFFSET,
         MirOp.CSTR,
         MirOp.VIEW,
         MirOp.VIEW_LEN,
         MirOp.ELEM_ADDR,
         MirOp.FIELD_ADDR,
         MirOp.TLS_BLOCK,
         MirOp.GLOBAL_BLOCK,
         MirOp.SIZEOF,
         MirOp.EXC_FRAME,
         MirOp.SETJMP,
         MirOp.LONGJMP,
         MirOp.VA_START,
         MirOp.ALLOCA,
         MirOp.VTABLE_ADDR,
         MirOp.CLASS_ADDR,
         MirOp.FN_ADDR,
         MirOp.CALL_DTOR,
         MirOp.GLOBAL_ADDR,
         MirOp.CALL_C,
         MirOp.CALL_FNPTR
     ],
     MEMORY_OPS: list[MirOp] = [
         MirOp.MEM_LOAD,
         MirOp.MEM_STORE,
         MirOp.ATOMIC_LOAD,
         MirOp.ATOMIC_STORE,
         MirOp.ATOMIC_RMW,
         MirOp.ATOMIC_CAS,
         MirOp.FENCE
     ],
     CMP_SYMBOLS: dict[str, str] = {
         "eq": "==",
         "ne": "!=",
         "lt": "<",
         "gt": ">",
         "le": "<=",
         "ge": ">="
     };

class MirEmitError(Exception) {}

obj MirEmitter {
    has mir: MirModule,
        module: ir.Module,
        functions: dict[str, ir.Function] = {},
        values: dict[int, ir.Value] = {},
        blocks: dict[str, ir.Block] = {},
        strings: dict[str, ir.GlobalVariable] = {},
        building: set[str] = set(),
        defined: set[str] = set(),
        literals: dict[str, ir.GlobalVariable] = {},
        byte_literals: dict[str, ir.GlobalVariable] = {},
        native_tls: bool = False,
        native_sjlj: bool = False,
        volatile_slots: bool = False,
        c_plans: dict[str, tuple[any, list[any]]] = {};

    def emit -> ir.Module;
    def llvm_type(t: MirType) -> ir.Type;
    def slot_type(t: MirType) -> ir.Type;
    def fn_type(params: list[MirType], ret: MirType) -> ir.FunctionType;
    def declare(fn: MirFunction) -> ir.Function;
    def extern(
        symbol: str, ret: ir.Type, args: list[ir.Type], variadic: bool = False
    ) -> ir.Function;

    def emit_function(fn: MirFunction);
    def c_layout(t: MirType) -> tuple[int, int, list[tuple[int, bool, int]]];
    def c_classify(t: MirType) -> dict[str, any];
    def c_abi_extern(ext: MirExtern) -> ir.Function;
    def entry_alloca(b: ir.IRBuilder, shape: ir.Type) -> ir.Value;
    def call_c_abi(b: ir.IRBuilder, callee: ir.Function, instr: MirInstr) -> ir.Value;
    def c_thunk(fn: MirFunction);
    def emit_instr(b: ir.IRBuilder, instr: MirInstr);
    def value(v: MirValue) -> ir.Value;
    def bind(v: (MirValue | None), made: ir.Value);
    def cstring(b: ir.IRBuilder, text: str) -> ir.Value;
    def cstring_global(text: str) -> ir.GlobalVariable;
    def c_constant(made: MirConst, shape: ir.Type) -> ir.Constant;
    def emit_bin(b: ir.IRBuilder, instr: MirInstr) -> ir.Value;
    def emit_floordiv(
        b: ir.IRBuilder, l: ir.Value, r: ir.Value, signed: bool
    ) -> ir.Value;

    def emit_mod(b: ir.IRBuilder, l: ir.Value, r: ir.Value, signed: bool) -> ir.Value;
    def emit_float_mod(b: ir.IRBuilder, l: ir.Value, r: ir.Value) -> ir.Value;
    def emit_ovf(b: ir.IRBuilder, instr: MirInstr) -> ir.Value;
    def emit_cmp(b: ir.IRBuilder, instr: MirInstr) -> ir.Value;
    def emit_conv(
        b: ir.IRBuilder, value: ir.Value, src: MirType, dst: MirType
    ) -> ir.Value;

    def emit_raise(b: ir.IRBuilder, instr: MirInstr);
    def str_type -> ir.Type;
    def jacval_type -> ir.Type;
    def emit_any(b: ir.IRBuilder, instr: MirInstr);
    def any_bits(b: ir.IRBuilder, value: ir.Value, t: MirType) -> ir.Value;
    def str_literal(b: ir.IRBuilder, text: str) -> ir.Value;
    def bytes_literal(b: ir.IRBuilder, data: bytes) -> ir.Value;
    def emit_rc(b: ir.IRBuilder, instr: MirInstr);
    def rc_call(b: ir.IRBuilder, symbol: str, target: ir.Value);
    def extern_call(
        b: ir.IRBuilder,
        symbol: str,
        ret: ir.Type,
        params: list[ir.Type],
        values: list[ir.Value]
    ) -> ir.Value;

    def call_declared(
        b: ir.IRBuilder, callee: ir.Function, instr: MirInstr
    ) -> ir.Value;

    def adapt(b: ir.IRBuilder, value: ir.Value, wanted: ir.Type) -> ir.Value;
    def emit_c(b: ir.IRBuilder, instr: MirInstr);
    def emit_memory(b: ir.IRBuilder, instr: MirInstr);
    def c_struct(name: str) -> ir.Type;
    def tls_block(label: str, size: int) -> ir.GlobalVariable;
    def global_block(label: str, size: int) -> ir.GlobalVariable;
    def object_struct(name: str) -> ir.Type;
    def vtable_global(obj_def: MirObjectDef) -> ir.GlobalVariable;
    def class_global(obj_def: MirObjectDef) -> ir.GlobalVariable;
    def global_variable(glob_def: MirGlobal) -> ir.GlobalVariable;
    def keyed_block_fn(label: str, size: int) -> ir.Function;
    def builtin_sjlj -> bool;
    def jmp_symbols -> tuple[str, str];
}

def emit_mir_module(
    mir: MirModule,
    triple: str = "",
    native_tls: bool = False,
    data_layout: str = "",
    native_sjlj: bool = False
) -> ir.Module;

def result_of(instr: MirInstr) -> MirValue;

def emission_order(fn: MirFunction) -> list[MirBlock];

def type_arg_of(instr: MirInstr) -> MirType;
