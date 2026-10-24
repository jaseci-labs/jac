impl SymbolTree.init(
    self: SymbolTree,
    node_name: str,
    parent: (SymbolTree | None) = None,
    children: (list[SymbolTree] | None) = None
) -> None {
    self.parent = parent;
    self.kid = children if (children is not None) else [];
    self.name = node_name;
}

impl SymbolTree.parent.getter -> (SymbolTree | None) {
    return self.__parent;
}

impl SymbolTree.parent.setter(self: SymbolTree, parent_node: (SymbolTree | None)) {
    if parent_node {
        self.__parent = parent_node;
        parent_node.kid.append(self);
    }
}

impl node_to_dict(nd: UniNode) -> dict[(str, str)] {
    ret = {
        'node': str(`type(nd).__name__),
        'kid': str(
            [
                node_to_dict(x)
                for x in [nd->:Kid:->]
                if x
            ]
        ),
        'line': str(nd.loc.first_line),
        'col': str(nd.loc.col_start)
    };
    if isinstance(nd, uni.Token) {
        ret['name'] = nd.name;
        ret['value'] = nd.value;
    }
    return ret;
}

impl printgraph_ast_tree(
    root_node: UniNode, dot_lines: (list[str] | None) = None
) -> str {
    starting_call = False;
    if (dot_lines is None) {
        starting_call = True;
        dot_lines = [];
    }
    """Generate number for each nodes.""";
    def gen_node_id(nd: uni.UniNode) -> int {
        if (id(nd) not in id_bag) {
            id_bag[id(nd)] = id_state["used"];
            id_state["used"] += 1;
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
    dot_lines.append(f"{gen_node_id(root_node)} {gen_node_parameters(root_node)};");
    for i in [root_node->:Kid:->] {
        dot_lines.append(f"{gen_node_id(root_node)}  -> {gen_node_id(i)};");
        printgraph_ast_tree(i, dot_lines);
    }
    if starting_call {
        return '\ndigraph graph1 {\n' + '\n'.join(`list(`set(dot_lines))) + '\n}';
    }
    return ' ';
}

impl print_ast_tree(
    root_node: (UniNode | ast3.AST),
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    max_depth: (int | None) = None
) -> str {
    print_py_raise: bool = False;
    def __node_repr_in_tree(nd: UniNode) -> str {
        access = f"Access: {nd.access.tag.value} ,"
            if (isinstance(nd, uni.AstAccessNode) and (nd.access is not None))
            else '';
        sym_table_link = f"SymbolTable: {nd.type_sym_tab.scope_name}"
            if (isinstance(nd, AstSymbolNode) and nd.type_sym_tab)
            else 'SymbolTable: None' if isinstance(nd, AstSymbolNode) else '';
        if (isinstance(nd, AstSymbolNode) and isinstance(nd, Token)) {
            type_str = str(nd.type) if (isinstance(nd, uni.Expr) and nd.type) else '';
            out = f"{nd.__class__.__name__} - {nd.value} - Type: {type_str}, {access} {sym_table_link}";
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
            resolved_path: (str | None) = None;
            try {
                resolved_path = nd.resolve_relative_path();
            } except Exception {
                resolved_path = nd.abs_path;
            }
            out = f"{nd.__class__.__name__} - {name_str} - abs_path: {resolved_path}";
            return out;
        } elif isinstance(nd, uni.ModulePath) {
            path_str: (str | None) = None;
            try {
                path_str = nd.resolve_relative_path();
            } except Exception {
                path_str = nd.abs_path;
            }
            out = f"{nd.__class__.__name__} - {'.'.join(
                [n.value for n in nd.path] if nd.path else []
            )} - abs_path: {path_str}";
            return out;
        } elif isinstance(nd, AstSymbolNode) {
            type_str = str(nd.name_spec.type)
                if (
                    nd?.name_spec
                    and isinstance(nd.name_spec, uni.Expr)
                    and nd.name_spec.type
                )
                else '';
            out = f"{nd.__class__.__name__} - {nd.sym_name} - Type: {type_str}, {access} {sym_table_link}";
            return out;
        } elif isinstance(nd, uni.Expr) {
            type_str = str(nd.type) if nd.type else '';
            return f"{nd.__class__.__name__} - Type: {type_str}";
        } else {
            return f"{nd.__class__.__name__}, {access}";
        }
    }
    def __node_repr_in_py_tree(nd: ast3.AST) -> str {
        if isinstance(nd, ast3.Constant) {
            return f"{nd.__class__.__name__} - {nd.value!r}";
        } elif isinstance(nd, ast3.Name) {
            return f"{nd.__class__.__name__} - {nd.id}";
        } elif isinstance(
            nd, (ast3.FunctionDef, ast3.ClassDef, ast3.AsyncFunctionDef)
        ) {
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
        if not isinstance(
            nd,
            (
                ast3.stmt,
                ast3.expr,
                ast3.excepthandler,
                ast3.arg,
                ast3.keyword,
                ast3.alias,
                ast3.pattern,
                ast3.type_param
            )
        ) {
            return '-:- - -:-';
        }
        if (nd.lineno and nd.col_offset and nd.end_lineno and nd.end_col_offset) {
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
        (root_node is None)
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
    markers = ''.join(
        [connection_str if draw else empty_str for draw in level_markers[:-1]]
    );
    markers += marker if (level > 0) else '';
    if isinstance(root_node, uni.UniNode) {
        tree_str = f"{root_node.loc}	{markers}{__node_repr_in_tree(root_node)}\n";
        if (
            isinstance(root_node, uni.Module)
            and root_node.is_raised_from_py
            and not print_py_raise
        ) {
            kids: Sequence[UniNode] = [
                x
                for x in root_node.get_all_sub_nodes(uni.Module)
                if x.is_raised_from_py
            ];
        } else {
            kids = [root_node->:Kid:->];
        }
        for (i, child) in enumerate(kids) {
            is_last = i == (len(kids) - 1);
            tree_str += print_ast_tree(
                child, marker, [*level_markers, not is_last], output_file, max_depth
            );
        }
    } elif isinstance(root_node, ast3.AST) {
        tree_str = f"{get_location_info(root_node)}	{markers}{__node_repr_in_py_tree(
            root_node
        )}\n";
        for (i_a, child_a) in enumerate(ast3.iter_child_nodes(root_node)) {
            is_last = i_a == (len(`list(ast3.iter_child_nodes(root_node))) - 1);
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

impl _build_symbol_tree_common(
    nd: UniScopeNode, parent_node: (SymbolTree | None) = None
) -> SymbolTree {
    root_node = SymbolTree(
        node_name=f"SymTable::{nd.__class__.__name__}({nd.scope_name})",
        parent=parent_node
    );
    symbols = SymbolTree(node_name='Symbols', parent=root_node);
    children = SymbolTree(node_name='Sub Tables', parent=root_node);
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
    return root_node;
}

impl print_symtab_tree(
    root_node: UniScopeNode,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str {
    return get_symtab_tree_str(
        _build_symbol_tree_common(root_node), marker, level_markers, output_file, depth
    );
}

impl get_symtab_tree_str(
    root_node: SymbolTree,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str {
    if ((root_node is None) or (depth == 0) or (root_node.name in dir(builtins))) {
        return '';
    }
    level_markers: list[bool] = level_markers or [];
    markers = (
        ''.join(
            [
                ('|' + (' ' * (len(marker) - 1))) if draw else (' ' * len(marker))
                for draw in level_markers[:-1]
            ]
        )
            + marker
            if level_markers
            else ''
    );
    line = f"{markers}{root_node.name}\n";
    if output_file {
        with open(output_file, 'a+') as f {
            f.write(line);
        }
    }
    return (
        line
        + ''.join(
            get_symtab_tree_str(
                child,
                marker,
                (level_markers + [(i < (len(root_node.kid) - 1))]),
                output_file,
                None if (depth is None) else (depth - 1)
            ) for (i, child) in enumerate(root_node.kid)
        )
    );
}

impl printgraph_symtab_tree(nd: UniScopeNode) -> str {
    dot_lines = [];
    id_map: dict[int, int] = {};
    last_id_state: dict[str, int] = {"used": 0};
    def gen_node_id(nd: SymbolTree) -> int {
        if (id(nd) not in id_map) {
            id_map[id(nd)] = last_id_state["used"];
            last_id_state["used"] += 1;
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
    def gen_dot_graph(nd: SymbolTree) {
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
