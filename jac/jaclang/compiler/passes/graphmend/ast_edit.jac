obj GraphMendFacts {
    has breaks: dict[(UniNode, GraphBreakKind)] = {},
        boundary: dict[(Ability, Ability)] = {},
        helpers: set[GraphMendHelper] = set(),
        noop: bool = False,
        disabled: (list[str] | None) = None,
        region: (str | None) = None,
        wrapped_keys: set[str] = set(),
        covered_by: dict[(str, str)] = {},
        callers: dict[(int, list[tuple[(Ability, bool)]])] = {};
}

def facts_for(nd: uni.UniNode) -> GraphMendFacts;

def gen_name(at: uni.UniNode, value: str, store: bool) -> uni.Name;

def gen_string(at: uni.UniNode, value: str) -> uni.String;

def gen_bool(at: uni.UniNode, value: bool) -> uni.Bool;

def need_helper(at: uni.UniNode, helper: GraphMendHelper);

def torch_call(at: uni.UniNode, fname: str, args: list[uni.Expr]) -> uni.FuncCall;

def split_params(params: any) -> tuple[list[uni.Expr], list[uni.KWPair]];

def split_params_keyed(params: any) -> tuple[list[uni.Expr], dict[str, uni.KWPair]];

def stmt_slot(
    at: uni.UniNode
) -> (tuple[uni.UniNode, uni.UniNode, list[uni.UniNode]] | None);

def _splice(parent: uni.UniNode, body: list[uni.UniNode], kids: list[uni.UniNode]);

def insert_after(stmt: uni.UniNode, new_stmt: uni.UniNode) -> bool;

def insert_before(stmt: uni.UniNode, new_stmt: uni.UniNode) -> bool;

def append_stmt(owner: uni.UniNode, new_stmt: uni.UniNode) -> bool;

def replace_stmt(old: uni.UniNode, new_nodes: list[uni.UniNode]) -> bool;
