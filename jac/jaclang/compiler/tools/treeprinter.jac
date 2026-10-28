import ast as ast3;
import builtins;
import html;

glob id_bag: dict[int, any] = {},
     id_state: dict[str, int] = {"used": 0},
     CLASS_COLOR_MAP: dict[(str, str)] = {
         'Expr': '#fbeb93',
         'AtomExpr': '#fbeb93',
         'ElementStmt': '#d8f3dc',
         'ArchBlockStmt': '#a8dadc',
         'EnumBlockStmt': '#89c6b3',
         'CodeBlockStmt': '#ffc596',
         'AstImplOnlyNode': '#a8dadc',
         'AstImplNeedingNode': '#a3d3f0',
         'NameAtom': '#cafafa',
         'ArchSpec': '#a3d3f0',
         'MatchPattern': '#a0d8b3',
         'SubTag': '#cafafa',
         'Module': '#D1FFE2  ',
         'GlobalVars': '#e1d1ff',
         'Test': '#e1d1ff',
         'ModuleCode': '#e1d1ff',
         'PyInlineCode': '#e1d1ff',
         'Import': '#e1d1ff',
         'ModulePath': '#e1d1ff',
         'ModuleItem': '#e1d1ff',
         'Archetype': '#a8dadc',
         'ArchDef': '#a3d3f0',
         'Enum': '#89c6b3',
         'EnumDef': '#89c6b3',
         'Ability': '#f9d69e',
         'AbilityDef': '#f9d69e',
         'FuncSignature': '#f9d69e',
         'EventSignature': '#f9d69e',
         'ArchRefChain': '#a3d3f0',
         'ParamVar': '#ffc596',
         'ArchHas': '#a8dadc',
         'HasVar': '#a3d3f0',
         'TypedCtxBlock': '#ffc596',
         'IfStmt': '#ccee9b',
         'ElseIf': '#ccee9b',
         'ElseStmt': '#ccee9b',
         'ExprStmt': '#d8f3dc',
         'TryStmt': '#ccee9b',
         'Except': '#d8f3dc',
         'FinallyStmt': '#d8f3dc',
         'IterForStmt': '#ccee9b',
         'InForStmt': '#ccee9b',
         'WhileStmt': '#ccee9b',
         'WithStmt': '#ccee9b',
         'ExprAsItem': '#ffc596',
         'RaiseStmt': '#d8f3dc',
         'AssertStmt': '#d8f3dc',
         'CheckStmt': '#d8f3dc',
         'CtrlStmt': '#d8f3dc',
         'DeleteStmt': '#d8f3dc',
         'ReportStmt': '#d8f3dc',
         'ReturnStmt': '#d8f3dc',
         'IgnoreStmt': '#d8f3dc',
         'VisitStmt': '#d8f3dc',
         'RevisitStmt': '#d8f3dc',
         'DisengageStmt': '#d8f3dc',
         'AwaitExpr': '#fbeb93',
         'CastExpr': '#fbeb93',
         'Assignment': '#ffc596',
         'BinaryExpr': '#fbeb93',
         'CompareExpr': '#fbeb93',
         'CfgExpr': '#fbeb93',
         'BoolExpr': '#fbeb93',
         'LambdaExpr': '#fbeb93',
         'UnaryExpr': '#fbeb93',
         'IfElseExpr': '#fbeb93',
         'MultiString': '#fccca4',
         'FString': '#ffc596',
         'ListVal': '#ffc596',
         'SetVal': '#ffc596',
         'TupleVal': '#ffc596',
         'DictVal': '#ffc596',
         'KVPair': '#ffc596',
         'KWPair': '#ffc596',
         'InnerCompr': '#fdc4df',
         'ListCompr': '#fdc4df',
         'GenCompr': '#ffc1de',
         'SetCompr': '#fdc4df',
         'DictCompr': '#fdc4df',
         'AtomTrailer': '#ffc596',
         'AtomUnit': '#ffc596',
         'YieldExpr': '#fbeb93',
         'FuncCall': '#fbeb93',
         'IndexSlice': '#fbeb93',
         'ArchRef': '#a8dadc',
         'EdgeRefTrailer': '#fbeb93',
         'EdgeOpRef': '#fbeb93',
         'DisconnectOp': '#fbeb93',
         'ConnectOp': '#fbeb93',
         'FilterCompr': '#fdc4df',
         'AssignCompr': '#fdc4df',
         'MatchStmt': '#a0d8b3',
         'MatchCase': '#a0d8b3',
         'MatchOr': '#a0d8b3',
         'MatchAs': '#a0d8b3',
         'MatchWild': '#a0d8b3',
         'MatchValue': '#a0d8b3',
         'MatchSingleton': '#a0d8b3',
         'MatchSequence': '#a0d8b3',
         'MatchMapping': '#a0d8b3',
         'MatchKVPair': '#a0d8b3',
         'MatchStar': '#a0d8b3',
         'MatchArch': '#a0d8b3',
         'Token': '#f0efef',
         'Name': '#cafafa',
         'SpecialVarRef': '#cafafa',
         'Literal': '#f1cfc4',
         'BuiltinType': '#f1cfc4',
         'Float': '#f1cfc4',
         'Int': '#f1cfc4',
         'String': '#f1cfc4',
         'Bool': '#f1cfc4',
         'Null': '#f1cfc4',
         'Ellipsis': '#f1cfc4',
         'EmptyToken': '#f1cfc4',
         'Semi': '#f1cfc4'
     };

def node_to_dict(nd: UniNode) -> dict[(str, str)];

def printgraph_ast_tree(
    root_node: UniNode, dot_lines: (list[str] | None) = None
) -> str;

def print_ast_tree(
    root_node: (UniNode | ast3.AST),
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    max_depth: (int | None) = None
) -> str;

class SymbolTree {
    def init(
        self: SymbolTree,
        node_name: str,
        parent: (SymbolTree | None) = None,
        children: (list[SymbolTree] | None) = None
    ) -> None;

    has parent: (SymbolTree | None) {
        getter;
        setter(self: SymbolTree, parent_node: (SymbolTree | None));
    }
}

def _build_symbol_tree_common(
    nd: UniScopeNode, parent_node: (SymbolTree | None) = None
) -> SymbolTree;

def print_symtab_tree(
    root_node: UniScopeNode,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str;

def get_symtab_tree_str(
    root_node: SymbolTree,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str;

def printgraph_symtab_tree(nd: UniScopeNode) -> str;
