"""Tree Printing Helpers for Jac."""
import ast as ast3;
import builtins;
import html;
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.unitree { UniNode, UniScopeNode }
    }
}

glob id_bag: dict = {},
     id_used: int = 0,
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
         'GlobalStmt': '#ffc596',
         'NonLocalStmt': '#ffc596',
         'Assignment': '#ffc596',
         'BinaryExpr': '#fbeb93',
         'CompareExpr': '#fbeb93',
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

"""Recursively generate ast tree in dot format."""
def printgraph_ast_tree(`root: UniNode, dot_lines: (list[str] | None) = None) -> str {
    starting_call = False;
    if (dot_lines is None) {
        starting_call = True;
        dot_lines = [];
    }
    """Generate number for each nodes.""";
    def gen_node_id(nd: uni.UniNode) -> int {
        global id_used;
        if (id(nd) not in id_bag) {
            id_bag[id(nd)] = id_used;
            id_used += 1;
        }
        return id_bag[id(nd)];
    }
    def gen_node_parameters(nd: uni.UniNode) -> str {
        shape = '';
        fillcolor = '';
        style = '';
        _class__ = str(nd.__class__)[33:-2];
        if (_class__ in CLASS_COLOR_MAP) {
            shape = 'shape="oval"';
            style = 'style="filled"';
            fillcolor = f'fillcolor="{CLASS_COLOR_MAP[_class__]}"';
        }
        info1: list[tuple[(str, str, str)]] = [];
        if isinstance(nd, uni.Token) {
            ' "Only tokens and some declared types are box(others are oval )';
            shape = 'shape="box"';
            info1.append(('name', '=', nd.name));
            info1.append(('value', '=', html.escape(nd.value)));
        }
        if (len(info1) == 0) {
            label = f'"{nd.__class__.__name__}"';
        } else {
            label = f"<{nd.__class__.__name__}";
            for i in info1 {
                label += f"<BR/> {i[0]}{i[1]}{i[2]}";
            }
            label += '>';
        }
        label = f"{label} {shape} {style} {fillcolor}".strip();
        return f"[label={label}]";
    }
    dot_lines.append(f"{gen_node_id(root)} {gen_node_parameters(root)};");
    for i in `root.kid {
        dot_lines.append(f"{gen_node_id(root)}  -> {gen_node_id(i)};");
        printgraph_ast_tree(i, dot_lines);
    }
    if starting_call {
        return '\ndigraph graph1 {\n' + '\n'.join(`list(`set(dot_lines))) + '\n}';
    }
    return ' ';
}

"""Recursively print ast tree."""
def print_ast_tree(
    `root: (UniNode | ast3.AST),
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    max_depth: (int | None) = None
) -> str {
    import from jaclang.jac0core.unitree { AstSymbolNode, Token }
    print_py_raise: bool = False;
    def __node_repr_in_tree(nd: UniNode) -> str {
        access = f"Access: {nd.access.tag.value} ,"
        if (isinstance(nd, uni.AstAccessNode) and (nd.access is not None))
        else '';
        sym_table_link = f"SymbolTable: {nd.type_sym_tab.scope_name}"
        if (isinstance(nd, AstSymbolNode) and nd.type_sym_tab)
        else 'SymbolTable: None' if isinstance(nd, AstSymbolNode) else '';
        if (isinstance(nd, Token) and isinstance(nd, AstSymbolNode)) {
            out = f"{nd.__class__.__name__} - {nd.value} - Type: {nd.expr_type}, {access} {sym_table_link}";
            return out;
        } elif isinstance(nd, Token) {
            return f"{nd.__class__.__name__} - {nd.value}, {access}";
        } elif (
            isinstance(nd, uni.Module) and nd.is_raised_from_py and not print_py_raise
        ) {
            return f"{nd.__class__.__name__} - PythonModuleRaised: {nd.name}";
        } elif isinstance(nd, uni.ModuleItem) {
            name_str = nd.name.sym_name
            if isinstance(nd.name, uni.Name)
            else nd.name.value;
            out = f"{nd.__class__.__name__} - {name_str} - abs_path: {nd.abs_path}";
            return out;
        } elif isinstance(nd, uni.ModulePath) {
            out = f"{nd.__class__.__name__} - {'.'.join(
                [n.value for n in nd.path] if nd.path else []
            )} - abs_path: {nd.abs_path}";
            return out;
        } elif isinstance(nd, AstSymbolNode) {
            out = f"{nd.__class__.__name__} - {nd.sym_name} - Type: {nd.expr_type}, {access} {sym_table_link}";
            return out;
        } elif isinstance(nd, uni.Expr) {
            return f"{nd.__class__.__name__} - Type: {nd.expr_type}";
        } else {
            return f"{nd.__class__.__name__}, {access}";
        }
    }
    def __node_repr_in_py_tree(nd: ast3.AST) -> str {
        if isinstance(nd, ast3.Constant) {
            return f"{nd.__class__.__name__} - {nd.value!r}";
        } elif isinstance(nd, ast3.Name) {
            return f"{nd.__class__.__name__} - {nd.id}";
        } elif isinstance(nd, ast3.FunctionDef | ast3.ClassDef | ast3.AsyncFunctionDef) {
            return f"{nd.__class__.__name__} - {nd.name}";
        } elif isinstance(nd, ast3.Import) {
            return f"{nd.__class__.__name__} - {', '.join(
                alias.name for alias in nd.names
            )}";
        } elif isinstance(nd, ast3.ImportFrom) {
            return f"{nd.__class__.__name__} - {nd.module} : {', '.join(
                alias.name for alias in nd.names
            )}";
        } elif isinstance(nd, ast3.alias) {
            return f"{nd.__class__.__name__} - {nd.name}";
        } elif isinstance(nd, ast3.Attribute) {
            return f"{nd.__class__.__name__} - {nd.attr}";
        } elif isinstance(nd, ast3.Call) {
            if isinstance(nd.func, ast3.Name) {
                return f"{nd.__class__.__name__} - {nd.func.id}";
            } elif isinstance(nd.func, ast3.Attribute) {
                return f"{nd.__class__.__name__} - {nd.func.attr}";
            } else {
                return f"{nd.__class__.__name__}";
            }
        } else {
            return f"{nd.__class__.__name__}";
        }
    }
    def get_location_info(nd: ast3.AST) -> str {
        if (nd?.lineno and nd?.col_offset and nd?.end_lineno and nd?.end_col_offset) {
            start_pos = f"{nd.lineno}:{(nd.col_offset + 1)}";
            end_pos = f"{nd.end_lineno}:{(nd.end_col_offset + 1)
            if nd.end_col_offset
            else nd.col_offset}";
            prefix = f"{start_pos} - {end_pos}";
            return prefix;
        }
        return '-:- - -:-';
    }
    if (
        (`root is None)
        or ((max_depth is not None) and (len((level_markers or [])) >= max_depth))
    ) {
        return '';
    }
    empty_str = ' ' * len(marker);
    connection_str = '|' + empty_str[:-1];
    if not level_markers {
        level_markers = [];
    }
    level = len(level_markers);
    def mapper(draw: bool) -> str {
        return connection_str if draw else empty_str;
    }
    markers = ''.join(map(mapper, level_markers[:-1]));
    markers += marker if (level > 0) else '';
    if isinstance(`root, uni.UniNode) {
        tree_str = f"{root.loc}	{markers}{__node_repr_in_tree(root)}\n";
        if (
            isinstance(`root, uni.Module)
            and `root.is_raised_from_py
            and not print_py_raise
        ) {
            kids: list[UniNode] = [
                *filter(
                    lambda x: Any : x.is_raised_from_py,
                    `root.get_all_sub_nodes(uni.Module)
                )
            ];
        } else {
            kids = `root.kid;
        }
        for (i, child) in enumerate(kids) {
            is_last = i == (len(kids) - 1);
            tree_str += print_ast_tree(
                child, marker, [*level_markers, not is_last], output_file, max_depth
            );
        }
    } elif isinstance(`root, ast3.AST) {
        tree_str = f"{get_location_info(root)}	{markers}{__node_repr_in_py_tree(root)}\n";
        for (i_a, child_a) in enumerate(ast3.iter_child_nodes(`root)) {
            is_last = i_a == (len(`list(ast3.iter_child_nodes(`root))) - 1);
            tree_str += print_ast_tree(
                child_a, marker, [*level_markers, not is_last], output_file, max_depth
            );
        }
    }
    if (output_file and (level == 0)) {
        with open(output_file, 'w') as f {
            f.write(tree_str);
        }
    }
    return tree_str;
}

"""Symbol Tree Node."""
class SymbolTree {
    """Initialize Symbol Tree Node."""
    def init(
        self: SymbolTree,
        node_name: str,
        parent: (SymbolTree | None) = None,
        children: (list[SymbolTree] | None) = None
    ) -> None;

    """Get parent node."""
    @property
    def parent(self: SymbolTree) -> (SymbolTree | None) {
        return self.__parent;
    }

    """Set parent node."""
    @parent.setter
    def parent(self: SymbolTree, parent_node: (SymbolTree | None)) -> None {
        if parent_node {
            self.__parent = parent_node;
            parent_node.kid.append(self);
        }
    }
}

def _build_symbol_tree_common(
    nd: UniScopeNode, parent_node: (SymbolTree | None) = None
) -> SymbolTree {
    `root = SymbolTree(
        node_name=f"SymTable::{nd.__class__.__name__}({nd.scope_name})",
        parent=parent_node
    );
    symbols = SymbolTree(node_name='Symbols', parent=`root);
    children = SymbolTree(node_name='Sub Tables', parent=`root);
    syms_to_iterate = `set(nd.names_in_scope.values());
    for sym in syms_to_iterate {
        symbol_node = SymbolTree(node_name=f"{sym.sym_name}", parent=symbols);
        SymbolTree(node_name=f"{sym.access} {sym.sym_type}", parent=symbol_node);
        if (sym.decl and (sym.decl.loc.first_line > 0)) {
            SymbolTree(
                node_name=f"decl: line {sym.decl.loc.first_line}, col {sym.decl.loc.col_start}",
                parent=symbol_node
            );
            defn = SymbolTree(node_name='defn', parent=symbol_node);
            [
                SymbolTree(
                    node_name=f"line {n.loc.first_line}, col {n.loc.col_start}",
                    parent=defn
                ) for n in sym.defn
            ];
            uses = SymbolTree(node_name='uses', parent=symbol_node);
            [
                SymbolTree(
                    node_name=f"line {n.loc.first_line}, col {n.loc.col_start}",
                    parent=uses
                ) for n in sym.uses
            ];
        }
    }
    for k in nd.kid_scope {
        if (k.scope_name == 'builtins') {
            continue;
        }
        _build_symbol_tree_common(k, children);
    }
    return `root;
}

"""Recursively print symbol table tree."""
def print_symtab_tree(
    `root: UniScopeNode,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str {
    return get_symtab_tree_str(
        _build_symbol_tree_common(`root), marker, level_markers, output_file, depth
    );
}

"""Recursively print symbol table tree."""
def get_symtab_tree_str(
    `root: SymbolTree,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str {
    if ((`root is None) or (depth == 0) or (`root.name in dir(builtins))) {
        return '';
    }
    level_markers = level_markers or [];
    markers = (
        ''.join(
            [
                ('|' + (' ' * (len(marker) - 1))) if draw else (' ' * len(marker))
                for draw in level_markers[:-1]
            ]
        ) + marker
        if level_markers
        else ''
    );
    line = f"{markers}{root.name}\n";
    if output_file {
        with open(output_file, 'a+') as f {
            f.write(line);
        }
    }
    return (
        line + ''.join(
            get_symtab_tree_str(
                child,
                marker,
                (level_markers + [(i < (len(`root.kid) - 1))]),
                output_file,
                None if (depth is None) else (depth - 1)
            ) for (i, child) in enumerate(`root.kid)
        )
    );
}

"""Generate DOT graph representation of a symbol table tree."""
def printgraph_symtab_tree(nd: UniScopeNode) -> str {
    dot_lines = [];
    id_map = {};
    last_id_used = 0;
    def gen_node_id(nd: SymbolTree) -> int {
        nonlocal last_id_used ;
        if (id(nd) not in id_map) {
            id_map[id(nd)] = last_id_used;
            last_id_used += 1;
        }
        return id_map[id(nd)];
    }
    def gen_node_parameters(nd: SymbolTree) -> str {
        shape = '';
        fillcolor = '';
        style = '';
        label = f'"{nd.name}"';
        label = f"{label} {shape} {style} {fillcolor}".strip();
        return f"[label={label}]";
    }
    def gen_dot_graph(nd: SymbolTree) -> None {
        dot_lines.append(f"{gen_node_id(nd)} {gen_node_parameters(nd)};");
        for kid_node in nd.kid {
            if kid_node {
                if (kid_node.name in dir(builtins)) {
                    continue;
                }
                dot_lines.append(f"{gen_node_id(nd)}  -> {gen_node_id(kid_node)};");
                gen_dot_graph(kid_node);
            }
        }
    }
    gen_dot_graph(_build_symbol_tree_common(nd));
    dot_str = 'digraph graph1 {\n' + '\n'.join(dot_lines) + '\n}';
    return dot_str;
}
