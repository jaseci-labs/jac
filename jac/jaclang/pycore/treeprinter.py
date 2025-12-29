"""Tree Printing Helpers for Jac."""

from __future__ import annotations

import ast as ast3
import builtins
import html
from typing import TYPE_CHECKING

import jaclang.pycore.unitree as uni

if TYPE_CHECKING:
    from jaclang.pycore.unitree import UniNode, UniScopeNode

id_bag: dict = {}
id_used: int = 0
CLASS_COLOR_MAP: dict[str, str] = {
    "Expr": "#fbeb93",
    "AtomExpr": "#fbeb93",
    "ElementStmt": "#d8f3dc",
    "ArchBlockStmt": "#a8dadc",
    "EnumBlockStmt": "#89c6b3",
    "CodeBlockStmt": "#ffc596",
    "AstImplOnlyNode": "#a8dadc",
    "AstImplNeedingNode": "#a3d3f0",
    "NameAtom": "#cafafa",
    "ArchSpec": "#a3d3f0",
    "MatchPattern": "#a0d8b3",
    "SubTag": "#cafafa",
    "Module": "#D1FFE2  ",
    "GlobalVars": "#e1d1ff",
    "Test": "#e1d1ff",
    "ModuleCode": "#e1d1ff",
    "PyInlineCode": "#e1d1ff",
    "Import": "#e1d1ff",
    "ModulePath": "#e1d1ff",
    "ModuleItem": "#e1d1ff",
    "Archetype": "#a8dadc",
    "ArchDef": "#a3d3f0",
    "Enum": "#89c6b3",
    "EnumDef": "#89c6b3",
    "Ability": "#f9d69e",
    "AbilityDef": "#f9d69e",
    "FuncSignature": "#f9d69e",
    "EventSignature": "#f9d69e",
    "ArchRefChain": "#a3d3f0",
    "ParamVar": "#ffc596",
    "ArchHas": "#a8dadc",
    "HasVar": "#a3d3f0",
    "TypedCtxBlock": "#ffc596",
    "IfStmt": "#ccee9b",
    "ElseIf": "#ccee9b",
    "ElseStmt": "#ccee9b",
    "ExprStmt": "#d8f3dc",
    "TryStmt": "#ccee9b",
    "Except": "#d8f3dc",
    "FinallyStmt": "#d8f3dc",
    "IterForStmt": "#ccee9b",
    "InForStmt": "#ccee9b",
    "WhileStmt": "#ccee9b",
    "WithStmt": "#ccee9b",
    "ExprAsItem": "#ffc596",
    "RaiseStmt": "#d8f3dc",
    "AssertStmt": "#d8f3dc",
    "CheckStmt": "#d8f3dc",
    "CtrlStmt": "#d8f3dc",
    "DeleteStmt": "#d8f3dc",
    "ReportStmt": "#d8f3dc",
    "ReturnStmt": "#d8f3dc",
    "IgnoreStmt": "#d8f3dc",
    "VisitStmt": "#d8f3dc",
    "RevisitStmt": "#d8f3dc",
    "DisengageStmt": "#d8f3dc",
    "AwaitExpr": "#fbeb93",
    "GlobalStmt": "#ffc596",
    "NonLocalStmt": "#ffc596",
    "Assignment": "#ffc596",
    "BinaryExpr": "#fbeb93",
    "CompareExpr": "#fbeb93",
    "BoolExpr": "#fbeb93",
    "LambdaExpr": "#fbeb93",
    "UnaryExpr": "#fbeb93",
    "IfElseExpr": "#fbeb93",
    "MultiString": "#fccca4",
    "FString": "#ffc596",
    "ListVal": "#ffc596",
    "SetVal": "#ffc596",
    "TupleVal": "#ffc596",
    "DictVal": "#ffc596",
    "KVPair": "#ffc596",
    "KWPair": "#ffc596",
    "InnerCompr": "#fdc4df",
    "ListCompr": "#fdc4df",
    "GenCompr": "#ffc1de",
    "SetCompr": "#fdc4df",
    "DictCompr": "#fdc4df",
    "AtomTrailer": "#ffc596",
    "AtomUnit": "#ffc596",
    "YieldExpr": "#fbeb93",
    "FuncCall": "#fbeb93",
    "IndexSlice": "#fbeb93",
    "ArchRef": "#a8dadc",
    "EdgeRefTrailer": "#fbeb93",
    "EdgeOpRef": "#fbeb93",
    "DisconnectOp": "#fbeb93",
    "ConnectOp": "#fbeb93",
    "FilterCompr": "#fdc4df",
    "AssignCompr": "#fdc4df",
    "MatchStmt": "#a0d8b3",
    "MatchCase": "#a0d8b3",
    "MatchOr": "#a0d8b3",
    "MatchAs": "#a0d8b3",
    "MatchWild": "#a0d8b3",
    "MatchValue": "#a0d8b3",
    "MatchSingleton": "#a0d8b3",
    "MatchSequence": "#a0d8b3",
    "MatchMapping": "#a0d8b3",
    "MatchKVPair": "#a0d8b3",
    "MatchStar": "#a0d8b3",
    "MatchArch": "#a0d8b3",
    "Token": "#f0efef",
    "Name": "#cafafa",
    "SpecialVarRef": "#cafafa",
    "Literal": "#f1cfc4",
    "BuiltinType": "#f1cfc4",
    "Float": "#f1cfc4",
    "Int": "#f1cfc4",
    "String": "#f1cfc4",
    "Bool": "#f1cfc4",
    "Null": "#f1cfc4",
    "Ellipsis": "#f1cfc4",
    "EmptyToken": "#f1cfc4",
    "Semi": "#f1cfc4",
}


def printgraph_ast_tree(
    root: UniNode,
    dot_lines: list[str] | None = None,
) -> str:
    """Recursively generate ast tree in dot format."""
    starting_call = False
    if dot_lines is None:
        starting_call = True
        dot_lines = []

    def gen_node_id(node: uni.UniNode) -> int:
        """Generate number for each nodes."""
        global id_used
        if id(node) not in id_bag:
            id_bag[id(node)] = id_used
            id_used += 1
        return id_bag[id(node)]

    def gen_node_parameters(node: uni.UniNode) -> str:
        shape = ""
        fillcolor = ""
        style = ""
        _class__ = str(node.__class__)[33:-2]
        if _class__ in CLASS_COLOR_MAP:
            shape = 'shape="oval"'
            style = 'style="filled"'
            fillcolor = f'fillcolor="{CLASS_COLOR_MAP[_class__]}"'
        info1: list[tuple[str, str, str]] = []
        if isinstance(node, uni.Token):
            """ "Only tokens and some declared types are box(others are oval )"""
            shape = 'shape="box"'
            info1.append(("name", "=", node.name))
            info1.append(("value", "=", html.escape(node.value)))

        if len(info1) == 0:
            label = f'"{node.__class__.__name__}"'
        else:
            label = f"<{node.__class__.__name__}"
            for i in info1:
                label += f"<BR/> {i[0]}{i[1]}{i[2]}"
            label += ">"

        label = f"{label} {shape} {style} {fillcolor}".strip()
        return f"[label={label}]"

    dot_lines.append(f"{gen_node_id(root)} {gen_node_parameters(root)};")
    for i in root.kid:
        dot_lines.append(f"{gen_node_id(root)}  -> {gen_node_id(i)};")
        printgraph_ast_tree(i, dot_lines)
    if starting_call:
        return "\ndigraph graph1 {\n" + "\n".join(list(set(dot_lines))) + "\n}"
    return " "


def print_ast_tree(
    root: UniNode | ast3.AST,
    marker: str = "+-- ",
    level_markers: list[bool] | None = None,
    output_file: str | None = None,
    max_depth: int | None = None,
) -> str:
    """Recursively print ast tree."""
    from jaclang.pycore.unitree import AstSymbolNode, Token

    print_py_raise: bool = False

    def __node_repr_in_tree(node: UniNode) -> str:
        access = (
            f"Access: {node.access.tag.value} ,"
            if isinstance(node, uni.AstAccessNode) and node.access is not None
            else ""
        )
        sym_table_link = (
            f"SymbolTable: {node.type_sym_tab.scope_name}"
            if isinstance(node, AstSymbolNode) and node.type_sym_tab
            else "SymbolTable: None"
            if isinstance(node, AstSymbolNode)
            else ""
        )

        if isinstance(node, Token) and isinstance(node, AstSymbolNode):
            out = f"{node.__class__.__name__} - {node.value} - Type: {node.expr_type}, {access} {sym_table_link}"
            return out
        elif isinstance(node, Token):
            return f"{node.__class__.__name__} - {node.value}, {access}"
        elif (
            isinstance(node, uni.Module)
            and node.is_raised_from_py
            and not print_py_raise
        ):
            return f"{node.__class__.__name__} - PythonModuleRaised: {node.name}"
        elif isinstance(node, uni.ModuleItem):
            name_str = (
                node.name.sym_name
                if isinstance(node.name, uni.Name)
                else node.name.value
            )
            out = f"{node.__class__.__name__} - {name_str} - abs_path: {node.abs_path}"
            return out
        elif isinstance(node, uni.ModulePath):
            out = (
                f"{node.__class__.__name__} - {'.'.join([n.value for n in node.path] if node.path else [])} - "
                f"abs_path: {node.abs_path}"
            )
            return out
        elif isinstance(node, AstSymbolNode):
            out = f"{node.__class__.__name__} - {node.sym_name} - Type: {node.expr_type}, {access} {sym_table_link}"
            return out
        elif isinstance(node, uni.Expr):
            return f"{node.__class__.__name__} - Type: {node.expr_type}"
        else:
            return f"{node.__class__.__name__}, {access}"

    def __node_repr_in_py_tree(node: ast3.AST) -> str:
        if isinstance(node, ast3.Constant):
            return f"{node.__class__.__name__} - {node.value!r}"
        elif isinstance(node, ast3.Name):
            return f"{node.__class__.__name__} - {node.id}"
        elif isinstance(node, ast3.FunctionDef | ast3.ClassDef | ast3.AsyncFunctionDef):
            return f"{node.__class__.__name__} - {node.name}"
        elif isinstance(node, ast3.Import):
            return f"{node.__class__.__name__} - {', '.join(alias.name for alias in node.names)}"
        elif isinstance(node, ast3.ImportFrom):
            return f"{node.__class__.__name__} - {node.module} : {', '.join(alias.name for alias in node.names)}"
        elif isinstance(node, ast3.alias):
            return f"{node.__class__.__name__} - {node.name}"
        elif isinstance(node, ast3.Attribute):
            return f"{node.__class__.__name__} - {node.attr}"
        elif isinstance(node, ast3.Call):
            if isinstance(node.func, ast3.Name):
                return f"{node.__class__.__name__} - {node.func.id}"
            elif isinstance(node.func, ast3.Attribute):
                return f"{node.__class__.__name__} - {node.func.attr}"
            else:
                return f"{node.__class__.__name__}"
        else:
            return f"{node.__class__.__name__}"

    def get_location_info(node: ast3.AST) -> str:
        if (
            hasattr(node, "lineno")
            and hasattr(node, "col_offset")
            and hasattr(node, "end_lineno")
            and hasattr(node, "end_col_offset")
        ):
            start_pos = f"{node.lineno}:{node.col_offset + 1}"
            end_pos = f"{node.end_lineno}:{node.end_col_offset + 1 if node.end_col_offset else node.col_offset}"
            prefix = f"{start_pos} - {end_pos}"
            return prefix
        return "-:- - -:-"

    if root is None or (
        max_depth is not None and len(level_markers or []) >= max_depth
    ):
        return ""

    empty_str = " " * len(marker)
    connection_str = "|" + empty_str[:-1]
    if not level_markers:
        level_markers = []
    level = len(level_markers)  # recursion level

    def mapper(draw: bool) -> str:
        return connection_str if draw else empty_str

    markers = "".join(map(mapper, level_markers[:-1]))
    markers += marker if level > 0 else ""

    if isinstance(root, uni.UniNode):
        tree_str = f"{root.loc}\t{markers}{__node_repr_in_tree(root)}\n"
        if (
            isinstance(root, uni.Module)
            and root.is_raised_from_py
            and not print_py_raise
        ):
            kids: list[UniNode] = [
                *filter(
                    lambda x: x.is_raised_from_py,
                    root.get_all_sub_nodes(uni.Module),
                )
            ]
        else:
            kids = root.kid
        for i, child in enumerate(kids):
            is_last = i == len(kids) - 1
            tree_str += print_ast_tree(
                child, marker, [*level_markers, not is_last], output_file, max_depth
            )

    elif isinstance(root, ast3.AST):
        tree_str = (
            f"{get_location_info(root)}\t{markers}{__node_repr_in_py_tree(root)}\n"
        )
        for i_a, child_a in enumerate(ast3.iter_child_nodes(root)):
            is_last = i_a == len(list(ast3.iter_child_nodes(root))) - 1
            tree_str += print_ast_tree(
                child_a, marker, [*level_markers, not is_last], output_file, max_depth
            )

    # Write to file only at the top level call
    if output_file and level == 0:
        with open(output_file, "w") as f:
            f.write(tree_str)

    return tree_str


class SymbolTree:
    """Symbol Tree Node."""

    def __init__(
        self,
        node_name: str,
        parent: SymbolTree | None = None,
        children: list[SymbolTree] | None = None,
    ) -> None:
        """Initialize Symbol Tree Node."""
        self.parent = parent
        self.kid = children if children is not None else []
        self.name = node_name

    @property
    def parent(self) -> SymbolTree | None:
        """Get parent node."""
        return self.__parent

    @parent.setter
    def parent(self, parent_node: SymbolTree | None) -> None:
        """Set parent node."""
        if parent_node:
            self.__parent = parent_node
            parent_node.kid.append(self)


def _build_symbol_tree_common(
    node: UniScopeNode, parent_node: SymbolTree | None = None
) -> SymbolTree:
    root = SymbolTree(
        node_name=f"SymTable::{node.__class__.__name__}({node.scope_name})",
        parent=parent_node,
    )
    symbols = SymbolTree(node_name="Symbols", parent=root)
    children = SymbolTree(node_name="Sub Tables", parent=root)

    syms_to_iterate = set(node.names_in_scope.values())

    for sym in syms_to_iterate:
        symbol_node = SymbolTree(node_name=f"{sym.sym_name}", parent=symbols)
        SymbolTree(node_name=f"{sym.access} {sym.sym_type}", parent=symbol_node)

        if sym.decl and sym.decl.loc.first_line > 0:
            SymbolTree(
                node_name=f"decl: line {sym.decl.loc.first_line}, col {sym.decl.loc.col_start}",
                parent=symbol_node,
            )
            defn = SymbolTree(node_name="defn", parent=symbol_node)
            [
                SymbolTree(
                    node_name=f"line {n.loc.first_line}, col {n.loc.col_start}",
                    parent=defn,
                )
                for n in sym.defn
            ]
            uses = SymbolTree(node_name="uses", parent=symbol_node)
            [
                SymbolTree(
                    node_name=f"line {n.loc.first_line}, col {n.loc.col_start}",
                    parent=uses,
                )
                for n in sym.uses
            ]

    for k in node.kid_scope:
        if k.scope_name == "builtins":
            continue
        _build_symbol_tree_common(k, children)

    return root


def print_symtab_tree(
    root: UniScopeNode,
    marker: str = "+-- ",
    level_markers: list[bool] | None = None,
    output_file: str | None = None,
    depth: int | None = None,
) -> str:
    """Recursively print symbol table tree."""
    return get_symtab_tree_str(
        _build_symbol_tree_common(root),
        marker,
        level_markers,
        output_file,
        depth,
    )


def get_symtab_tree_str(
    root: SymbolTree,
    marker: str = "+-- ",
    level_markers: list[bool] | None = None,
    output_file: str | None = None,
    depth: int | None = None,
) -> str:
    """Recursively print symbol table tree."""
    if root is None or depth == 0 or root.name in dir(builtins):
        return ""

    level_markers = level_markers or []
    markers = "".join(
        [
            "|" + " " * (len(marker) - 1) if draw else " " * len(marker)
            for draw in level_markers[:-1]
        ]
    ) + (marker if level_markers else "")
    line = f"{markers}{root.name}\n"

    if output_file:
        with open(output_file, "a+") as f:
            f.write(line)

    return line + "".join(
        get_symtab_tree_str(
            child,
            marker,
            level_markers + [i < len(root.kid) - 1],
            output_file,
            None if depth is None else depth - 1,
        )
        for i, child in enumerate(root.kid)
    )


def printgraph_symtab_tree(node: UniScopeNode) -> str:
    """Generate DOT graph representation of a symbol table tree."""
    dot_lines = []
    id_map = {}
    last_id_used = 0

    def gen_node_id(node: SymbolTree) -> int:
        nonlocal last_id_used
        if id(node) not in id_map:
            id_map[id(node)] = last_id_used
            last_id_used += 1
        return id_map[id(node)]

    def gen_node_parameters(node: SymbolTree) -> str:
        shape = ""
        fillcolor = ""
        style = ""
        label = f'"{node.name}"'
        label = f"{label} {shape} {style} {fillcolor}".strip()
        return f"[label={label}]"

    def gen_dot_graph(node: SymbolTree) -> None:
        dot_lines.append(f"{gen_node_id(node)} {gen_node_parameters(node)};")
        for kid_node in node.kid:
            if kid_node:
                if kid_node.name in dir(builtins):
                    continue
                dot_lines.append(f"{gen_node_id(node)}  -> {gen_node_id(kid_node)};")
                gen_dot_graph(kid_node)

    gen_dot_graph(_build_symbol_tree_common(node))

    dot_str = "digraph graph1 {\n" + "\n".join(dot_lines) + "\n}"

    return dot_str
