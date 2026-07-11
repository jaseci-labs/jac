import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.ownership { Ownership, result_ownership }
import from jaclang.compiler.passes.main.type_facts_pass {
    TypeFacts,
    get_type_facts,
    type_tag_name,
    ScopeTypes
}

obj OwnershipFacts {
    has value_category: dict[int, Ownership] = {},
        last_uses: dict[int, bool] = {},
        consumed_params: dict[str, set[int]] = {};

    def category_of(nd: uni.UniNode) -> Ownership;
    def is_owned(nd: uni.UniNode) -> bool;
    def is_last_use(nd: uni.UniNode) -> bool;
    def is_consumed(key: str, idx: int) -> bool;
}

def get_ownership_facts(
    module: uni.Module, prog: JacProgram | None = None
) -> OwnershipFacts;

obj OwnershipFactsPass(Transform[uni.Module, uni.Module]) {
    has tf: TypeFacts = TypeFacts(),
        local_types: dict[str, str] = {},
        facts: OwnershipFacts = OwnershipFacts();

    def transform(ir_in: uni.Module) -> uni.Module;
    def analyze(mod: uni.Module);
    def tag_name(type_tag: uni.SubTag[uni.Expr] | None) -> str;
    def analyze_ability(ab: uni.Ability, cls: str);
    def compute_consumed(ab: uni.Ability, cls: str, body: list[uni.UniNode]);
    def callee_key(ab: uni.Ability, cls: str) -> str;
    def sole_field_store(body: list[uni.UniNode], pname: str) -> (uni.UniNode | None);
    def count_name(body: list[uni.UniNode], pname: str) -> int;
    def count_in_expr(e: object, pname: str) -> int;
    def is_straight_line(body: list[uni.UniNode]) -> bool;
    def categorize_stmt(st: object);
    def note_local_type(a: uni.Assignment);
    def categorize(e: object);
    def ownership_of(e: uni.Expr) -> Ownership;
    def is_str_concat(e: uni.Expr) -> bool;
    def type_of(e: object) -> str;
    def mark_last_uses(body: list[uni.UniNode]);
    def collect_reads(e: object, last_read: dict[str, uni.UniNode]);
}
