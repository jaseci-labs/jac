import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.compiler.passes.main.layout_pass {
    get_layout_registry,
    get_shared_layout_registry,
    LayoutRegistry
}
import from jaclang.compiler.passes.main.ownership_facts_pass {
    get_ownership_facts,
    OwnershipFacts
}
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
import from jaclang.compiler.passes.main.type_facts_pass {
    TypeFacts,
    get_shared_type_facts,
    ScopeTypes,
    is_ref_arch as arch_is_ref,
    type_tag_name,
    ret_type_name as sig_ret_name
}
import from jaclang.jac0core.diagnostics { DIAGNOSTICS }

glob C_PRIM_TYPES: dict[str, str] = {
         "int": "int",
         "float": "double",
         "bool": "int",
         "str": "const char*",
         "None": "void",
         "": "void"
     },
     C_OP_MAP: dict[str, str] = {"and": "&&", "or": "||", "not": "!"};

glob C_FIRST_USER_TYPEID: int = 2;

obj CGenPass(Transform[uni.Module, uni.Module]) {
    has type_ids: dict[str, int] = {},
        method_owners: dict[str, dict[str, str]] = {},
        method_defs: dict[str, dict[str, uni.Ability]] = {},
        arch_nodes: dict[str, uni.Archetype] = {},
        local_funcs: dict[str, bool] = {},
        tf: TypeFacts = TypeFacts(),
        shared_type_facts: TypeFacts | None = None,
        imported_mods: list[uni.Module] = [],
        local_types: dict[str, str] = {},
        owned_locals: list[str] = [],
        cur_class: str = "",
        cur_ret_cty: str = "int",
        tmp_ctr: int = 0,
        exc_ctr: int = 0,
        exc_frames: list[str] = [],
        needs_rt: bool = False,
        layout: LayoutRegistry | None = None,
        facts: OwnershipFacts | None = None,
        arg_pre: list[str] = [],
        arg_post: list[str] = [],
        cur_pad: str = "",
        hoist_ok: bool = False,
        extern_types: list[str] = [],
        extern_funcs: list[str] = [],
        extern_func_defs: dict[str, uni.Ability] = {},
        seen_imports: list[str] = [],
        shared_layout: LayoutRegistry | None = None,
        strict_c: bool = False;

    def transform(ir_in: uni.Module) -> uni.Module;
    def _unsupported(nd: uni.UniNode, code: str, **kw: object);
    def is_ref_arch(arch: uni.Archetype) -> bool;
    def classify(mod: uni.Module);
    def classify_imports(mod: uni.Module);
    def index_imported(sub: uni.Module);
    def index_arch(arch: uni.Archetype);
    def gen_module(mod: uni.Module);
    def extern_decls -> list[str];
    def load_layout(mod: uni.Module);
    def has_vtable(name: str) -> bool;
    def mro_of(name: str) -> list[str];
    def resolve_override(cls: str, m: str) -> str;
    def resolve_introducer(cls: str, m: str) -> str;
    def layout_fields(name: str) -> list;
    def c_type(jac_ty: str) -> str;
    def type_name(type_tag: uni.SubTag[uni.Expr] | None) -> str;
    def ret_type_name(ret: uni.Expr | None) -> str;
    def gen_struct(arch: uni.Archetype) -> str;
    def field_list(arch: uni.Archetype) -> list[uni.HasVar];
    def method_list(arch: uni.Archetype) -> list[uni.Ability];
    def find_init(arch: uni.Archetype) -> (uni.Ability | None);
    def gen_ref_struct(arch: uni.Archetype) -> str;
    def gen_vtable(arch: uni.Archetype) -> str;
    def ctor_head(arch: uni.Archetype) -> str;
    def method_head(arch: uni.Archetype, ab: uni.Ability) -> str;
    def ref_protos(arch: uni.Archetype) -> list[str];
    def gen_ref_defs(arch: uni.Archetype) -> list[str];
    def gen_dtor(arch: uni.Archetype) -> str;
    def all_fields(arch: uni.Archetype) -> list;
    def gen_ctor(arch: uni.Archetype) -> str;
    def field_defaults(arch: uni.Archetype) -> list;
    def gen_method(arch: uni.Archetype, ab: uni.Ability) -> str;
    def enter_method(cls: str);
    def func_head(ab: uni.Ability) -> str;
    def gen_func(ab: uni.Ability) -> str;
    def gen_block(stmts: object, ind: int) -> str;
    def scope_release_lines(pad: str, skip_name: str) -> list[str];
    def ref_field_store(st: uni.Assignment, pad: str) -> (str | None);
    def ref_local_copy(st: uni.Assignment, pad: str) -> (str | None);
    def gen_stmt(st: object, ind: int, is_last: bool) -> str;
    def render_stmt(st: object, ind: int, is_last: bool) -> str;
    def gen_for(st: uni.IterForStmt, ind: int) -> str;
    def gen_if(st: uni.IfStmt, ind: int) -> str;
    def exc_pop_lines(pad: str) -> list[str];
    def exc_type_name(e: object) -> str;
    def exc_match_cond(et: str, cname: str) -> str;
    def gen_raise(st: uni.RaiseStmt, ind: int) -> str;
    def gen_try(st: uni.TryStmt, ind: int) -> str;
    def gen_assign(a: uni.Assignment) -> str;
    def expr_type_name(e: object) -> str;
    def c_op(op_val: str) -> str;
    def gen_compare_clause(left: object, op_val: str, right: object) -> str;
    def gen_expr(e: object) -> str;
    def gen_call(e: uni.FuncCall) -> str;
    def gen_args(e: uni.FuncCall, callee_key: str) -> list;
    def emit_arg(p: uni.Expr, callee_key: str, idx: int) -> str;
    def virtual_call(
        recv_ty: str, mname: str, recv: str, slot: int, args: list
    ) -> str;

    def attr_name(nd: object) -> str;
}

def import_path(mp: uni.ModulePath) -> (str | None);

def direct_import_paths(mod: uni.Module) -> list[str];

def discover_import_graph(
    main_path: str, main_mod: uni.Module, prog: any, strict_c: bool = False
) -> list[tuple[str, uni.Module]];

def emit_translation_units(
    main_path: str, main_mod: uni.Module, prog: any
) -> list[tuple[str, str]];
