import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.constant { VALUE_ARCH_DECORATOR }
import from jaclang.compiler.type_system.types { TypeBase }

def is_ref_arch(arch: uni.Archetype) -> bool;

def type_tag_name(type_tag: uni.SubTag[uni.Expr] | None) -> str;

def ret_type_name(ret: uni.Expr | None) -> str;

obj ScopeTypes {
    static def for_ability(
        sig: object, self_type: str, scope: dict[str, str] = {}
    ) -> dict[str, str];
}

obj TypeFacts {
    has ref_types: dict[str, bool] = {},
        func_returns: dict[str, str] = {},
        method_returns: dict[str, dict[str, str]] = {},
        field_types: dict[str, dict[str, str]] = {},
        ok: bool = False,
        type_ids: (TypeIdIndex | None) = None,
        prog: (JacProgram | None) = None;

    def type_of(
        e: object, local_types: dict[str, str], scope: dict[str, str] = {}
    ) -> str;

    def type_of_via_checker(e: uni.Expr) -> str;
    def typebase_to_typename(ty: TypeBase | None) -> str;

    def is_ref(name: str) -> bool;
}

obj TypeIdIndex {
    has tids: dict[str, str] = {};

    def key(mod_path: str, name: str) -> str;
    def tid_for(mod_path: str, name: str) -> str;
    def tid_of_arch(arch: uni.Archetype) -> str;
    def has_arch(arch: uni.Archetype) -> bool;
    def scope_for(mod: uni.Module) -> dict[str, str];
}

def module_stem(mod_path: str) -> str;

def sanitize_c_ident(s: str) -> str;

def build_type_id_index(modules: list[uni.Module]) -> TypeIdIndex;

def get_type_facts(module: uni.Module, prog: JacProgram | None = None) -> TypeFacts;

def get_shared_type_facts(
    modules: list[uni.Module], prog: JacProgram | None = None
) -> TypeFacts;

obj TypeFactsPass(Transform) {
    has facts: TypeFacts = TypeFacts();

    def transform(ir_in: uni.Module) -> uni.Module;
    def index_module(mod: uni.Module);
    def index_arch(arch: uni.Archetype);
    def ret_name(ret: uni.Expr | None) -> str;
    def resolve_ann_token(ann: uni.Expr | None, syntactic: str) -> str;
}
