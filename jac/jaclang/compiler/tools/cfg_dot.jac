import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.compiler.frontend.unitree {
    Module,
    TreeWalker,
    UniNode,
    Ability,
    Archetype,
    AssertStmt,
    AstElseBodyNode,
    AtomUnit,
    AwaitingClause,
    BoolExpr,
    CfgExpr,
    CodeBlockStmt,
    CtrlStmt,
    DictCompr,
    DisengageStmt,
    ElseIf,
    ElseStmt,
    Except,
    Expr,
    FinallyStmt,
    ForeverStmt,
    GenCompr,
    GlobalVars,
    IfElseExpr,
    IfStmt,
    ImplDef,
    InForStmt,
    InnerCompr,
    IterForStmt,
    JsxSlot,
    LambdaExpr,
    ListCompr,
    MatchCase,
    MatchStmt,
    ModuleCode,
    Name,
    OpenStmt,
    RaiseStmt,
    ReturnStmt,
    SemDef,
    Semi,
    SetCompr,
    SwitchCase,
    SwitchStmt,
    Test,
    Token,
    TryStmt,
    TypeAlias,
    TypedCtxBlock,
    UniCFGNode,
    WhileStmt,
    WithStmt
}
import from jaclang.compiler.passes.context { CompileContext, TreePass }
import from typing { cast }
import from jaclang.compiler.passes.cfg_build_pass {
    is_structural_child,
    unwrap_to_bool
}

walker CoalesceBBPass(TreePass) {
    has basic_blocks: dict[int, dict[str, list[UniCFGNode]]] = {},
        bb_counter: int = 0;

    can prepare with entry;
    def get_bb(nd: UniCFGNode) -> list[UniCFGNode];
    can coalesce_collect with UniNode entry;
    def printgraph_cfg -> str;
    def _node_label(nd: UniNode) -> str;
    def _has_bool_sc(condition: Expr) -> bool;
}

def cfg_dot_from_file(file_name: str) -> str;
