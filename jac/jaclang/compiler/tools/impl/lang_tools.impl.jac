impl AstTool.autodoc_uninode -> str {
    output = '';
    tick = chr(96);
    fence = tick * 3;
    for cls in self.ast_classes {
        if not len(cls.kids) {
            continue;
        }
        output += '## ' + cls.name + '\n';
        output += fence + 'mermaid\nflowchart LR\n';
        for kid in cls.kids {
            if ('_end' in kid.name) {
                kid.name = kid.name.replace('_end', '_end_');
            }
            typ_str = str(kid.typ);
            arrow = '-.->' if ('Optional' in typ_str) else '-->';
            typ = typ_str.replace('typing.', '').replace(
                'jaclang.compiler.frontend.unitree.', ''
            ).replace(
                'Optional[', ''
            ).replace(
                'Union[', ''
            ).replace(
                'SubTag[', ''
            ).replace(
                'Sequence[', ''
            ).replace(
                'list[', 'list - '
            ).replace(
                ']', ''
            ).replace(
                '|', ','
            );
            output += f"{cls.name} {arrow}|{typ}| {kid.name}\n";
        }
        output += fence + '\n\n';
        output += f"{cls.doc}\n\n";
    }
    return output;
}

impl AstTool.ir(args: list[str]) -> str {
    error = 'Usage: ir <choose one of (sym / sym. / ast / ast. / cfg. / docir / pyast / py / unparse / esast / es)> <.py or .jac file_path>';
    if (len(args) != 2) {
        return error;
    }
    (output, file_name) = args;
    if not os.path.isfile(file_name) {
        return f"Error: {file_name} not found";
    }
    if not file_name.endswith(('.jac', '.py')) {
        return 'Not a .jac or .py file, or invalid command for file type.';
    }
    if output == 'pyast' and file_name.endswith('.py') {
        with open(file_name, encoding="utf-8") as handle {
            return py_ast.dump(py_ast.parse(handle.read()), indent=2);
        }
    }
    if output in ('pyast', 'py') {
        if not file_name.endswith('.jac') {
            return f"Invalid key: {error}";
        }
        compiled = call_compile(
            compile_request_for([file_name], CompileOptions(), {}, ["python_ast"])
        );
        if not compiled.ok() {
            return "\n".join([diagnostic_text(diag) for diag in compiled.errors]);
        }
        tree = compiled.unit(file_name).python_ast;
        return py_ast.dump(tree, indent=2)
            if output == 'pyast'
            else py_ast.unparse(tree);
    }
    if output not in IR_VIEWS {
        return f"Invalid key: {error}";
    }
    shown = tool_session().ast_view(file_name, output);
    if shown.text or not shown.errors {
        return shown.text;
    }
    return "\n".join([diagnostic_text(diag) for diag in shown.errors]);
}

impl AstTool.py_uni_nodes -> str {
    py_ast.unparse(py_ast.parse(""));
    visit_methods = [
        method
        for method in dir(py_ast._Unparser)
        if method.startswith('visit_')
    ];
    node_names = [method.replace('visit_', '') for method in visit_methods];
    pass_func_names: list[str] = [];
    for (member_name, member_value) in inspect.getmembers(PyastBuildPass) {
        if (member_name.startswith('proc_') and inspect.isfunction(member_value)) {
            pass_func_names.append(member_name.replace('proc_', ''));
        }
    }
    output = '';
    missing = [];
    for i in node_names {
        nd = pascal_to_snake(i);
        this_func = (
            f"def proc_{nd}(self, node: py_ast.{i}) -> ast.UniNode:\n"
            + '    """Process python node."""\n\n'
        );
        if (nd not in pass_func_names) {
            missing.append(this_func);
        }
        output += this_func;
    }
    for i in missing {
        output += "# missing: \n" + i + "\n";
    }
    return output;
}

impl AstTool.init -> None {
    module = sys.modules[uni.__name__];
    source_code = inspect.getsource(module);
    classes = inspect.getmembers(module, inspect.isclass);
    uni_node_classes = [
        UniNodeInfo(cls)
        for (_, cls) in classes
        if (
            issubclass(cls, uni.UniNode)
            and (
                cls.__name__
                not in [
                    'UniNode',
                    'UniScopeNode',
                    'UniCFGNode',
                    'ContextAwareNode',
                    'ProgramModule',
                    'OOPAccessNode',
                    'WalkerStmtOnlyNode',
                    'Source',
                    'EmptyToken',
                    'AstSymbolNode',
                    'AstSymbolStubNode',
                    'AstAccessNode',
                    'Literal',
                    'AstDocNode',
                    'AstImplNeedingNode',
                    'AstSemStrNode',
                    'PythonModuleAst',
                    'AstAsyncNode',
                    'AstElseBodyNode',
                    'AstTypedVarNode',
                    'AstImplOnlyNode',
                    'Expr',
                    'AtomExpr',
                    'ElementStmt',
                    'ArchBlockStmt',
                    'EnumBlockStmt',
                    'CodeBlockStmt',
                    'NameAtom',
                    'ArchSpec',
                    'MatchPattern'
                ]
            )
        )
    ];
    self.ast_classes = sorted(
        uni_node_classes,
        key=lambda (cls: any) { source_code.find(f"class {cls.name}"); }
    );
}

impl UniNodeInfo.process(cls: type[uni.UniNode]) -> None {
    self.name = cls.__name__;
    self.doc = cls.__doc__;
    UniNodeInfo.type_map[self.name] = cls;
    self.class_name_snake = pascal_to_snake(cls.__name__);
    self.init_sig = inspect.signature(cls.__init__);
    self.kids = [];
    for (param_name, param) in self.init_sig.parameters.items() {
        if (param_name not in ['self', 'parent', 'kid', 'line', 'sym_tab']) {
            param_type = param.annotation
                if (param.annotation != inspect.Parameter.empty)
                else 'Any';
            param_default = param.`default
                if (param.`default != inspect.Parameter.empty)
                else None;
            self.kids.append(AstKidInfo(param_name, param_type, param_default));
        }
    }
}

impl UniNodeInfo.postinit -> None {
    self.process(self.cls);
}
