glob RAISE_BUILTIN_SYMBOL: str = "__jac_rt_raise_builtin",
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
        native_tls: bool = False;

    def emit -> ir.Module;
    def llvm_type(t: MirType) -> ir.Type;
    def fn_type(params: list[MirType], ret: MirType) -> ir.FunctionType;
    def declare(fn: MirFunction) -> ir.Function;
    def extern(symbol: str, ret: ir.Type, args: list[ir.Type]) -> ir.Function;
    def emit_function(fn: MirFunction);
    def emit_instr(b: ir.IRBuilder, instr: MirInstr);
    def value(v: MirValue) -> ir.Value;
    def bind(v: (MirValue | None), made: ir.Value);
    def cstring(b: ir.IRBuilder, text: str) -> ir.Value;
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
    def emit_c(b: ir.IRBuilder, instr: MirInstr);
    def emit_memory(b: ir.IRBuilder, instr: MirInstr);
    def c_struct(name: str) -> ir.Type;
    def tls_block(label: str, size: int) -> ir.GlobalVariable;
    def global_block(label: str, size: int) -> ir.GlobalVariable;
    def global_variable(glob_def: MirGlobal) -> ir.GlobalVariable;
    def keyed_block_fn(label: str, size: int) -> ir.Function;
}

def emit_mir_module(
    mir: MirModule, triple: str = "", native_tls: bool = False
) -> ir.Module;

def result_of(instr: MirInstr) -> MirValue;

def type_arg_of(instr: MirInstr) -> MirType;
