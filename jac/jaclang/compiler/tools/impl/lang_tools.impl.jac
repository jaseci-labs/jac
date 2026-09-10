import from jaclang.cli.console { console }
import from jaclang.compiler.tools.unparse_pass { unparse_module }
import from jaclang.compiler.tools.treeprinter {
    print_ast_tree,
    print_symtab_tree,
    printgraph_ast_tree,
    printgraph_symtab_tree
}

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
    import from jaclang.compiler.driver.pass_driver { run_pass }
    error = 'Usage: ir <choose one of (sym / sym. / ast / ast. / docir / pyast / py / unparse / esast / es)> <.py or .jac file_path>';
    if (len(args) != 2) {
        return error;
    }
    (output, file_name) = args;
    prog = JacProgram();
    if not os.path.isfile(file_name) {
        return f"Error: {file_name} not found";
    }
    if file_name.endswith(('.jac', '.py')) {
        [base, mod] = os.path.split(file_name);
        base = base or './';
        if file_name.endswith('.py') {
            file_source = read_file_with_encoding(file_name);
            parsed_ast = py_ast.parse(file_source);
            if (output == 'pyast') {
                return f"{py_ast.dump(parsed_ast, indent=2)}";
            }
            try {
                rep = run_pass(
                    PyastBuildPass,
                    uni.PythonModuleAst(
                        parsed_ast, orig_src=uni.Source(file_source, file_name)
                    ),
                    prog
                ).ir_out;
                rep_src = unparse_module(rep);
                console.print(rep_src);
                ir_mod = prog.compile(
                    use_str=rep_src,
                    file_path=(file_name[:-3] + '.jac'),
                    options=CompileOptions(no_cgen=True)
                );
            } except Exception as e {
                return f"Error While Jac to Py AST conversion: {e}";
            }
        } else {
            ir_mod = prog.compile(file_name, options=CompileOptions(no_cgen=True));
        }
        match output {
            case 'sym':
                out = '';
                for module_ in prog.mod.hub.values() {
                    mod_name = module_.name;
                    t = '#' * len(mod_name);
                    out += '##'
                        + t
                        + '##\n# '
                        + mod_name
                        + ' #\n##'
                        + t
                        + '##\n'
                        + print_symtab_tree(root_node=module_.sym_tab)
                        + '\n';
                }
                return out;

            case 'sym.':
                return printgraph_symtab_tree(ir_mod.sym_tab)
                    if isinstance(ir_mod.sym_tab, UniScopeNode)
                    else 'Sym_tab is None.';

            case 'ast':
                out = '';
                for module_ in prog.mod.hub.values() {
                    mod_name = module_.name;
                    t = '#' * len(mod_name);
                    out += '##'
                        + t
                        + '##\n# '
                        + mod_name
                        + ' #\n##'
                        + t
                        + '##\n'
                        + print_ast_tree(module_)
                        + '\n';
                }
                return out;

            case 'ast.':
                return printgraph_ast_tree(ir_mod);

            case 'cfg.':
                return cfg_dot_from_file(file_name);

            case 'unparse':
                return unparse_module(ir_mod);

            case 'pyast':
                ir_mod = prog.compile(file_name, options=CompileOptions());
                return f"{py_ast.dump(ir_mod.gen.py_ast[0], indent=2)}"
                    if isinstance(ir_mod.gen.py_ast[0], py_ast.AST)
                    else 'Compile failed.';

            case 'docir':
                return str(run_pass(DocIRGenPass, ir_mod, prog).ir_out.gen.doc_ir);

            case 'py':
                ir_mod = prog.compile(file_name, options=CompileOptions());
                return f"{ir_mod.gen.py}"
                    if isinstance(ir_mod.gen.py[0], str)
                    else 'Compile failed.';

            case 'esast':
                esast_pass = run_pass(EsastGenPass, ir_mod, prog);
                es_ir = esast_pass.ir_out;
                es_ast = es_ir.gen.es_ast;
                if isinstance(es_ast, EsNode) {
                    return f"{json.dumps(es_node_to_dict(es_ast), indent=2)}";
                } else {
                    return 'ECMAScript AST generation failed.';
                }

            case 'es':
                esast_pass = run_pass(EsastGenPass, ir_mod, prog);
                es_ir = esast_pass.ir_out;
                es_ast = es_ir.gen.es_ast;
                if isinstance(es_ast, EsNode) {
                    return f"{es_to_js(es_ast)}";
                } else {
                    return 'ECMAScript code generation failed.';
                }

            case _:
                return f"Invalid key: {error}";

        }
    } else {
        return 'Not a .jac or .py file, or invalid command for file type.';
    }
}

impl AstTool.py_uni_nodes -> str {
    import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }

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
