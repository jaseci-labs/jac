"""Generate mermaid markdown doc for uninodes."""
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
            typ = typ_str.replace('typing.', '').replace('jaclang.pycore.unitree.', '').replace(
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

"""Generate a AST, SymbolTable tree for .jac file, or Python AST for .py file."""
impl AstTool.ir(args: list[str]) -> str {
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
                rep = PyastBuildPass(
                    ir_in=uni.PythonModuleAst(
                        parsed_ast, orig_src=uni.Source(file_source, file_name)
                    ),
                    prog=prog
                ).ir_out;
                print(rep.unparse());
                ir = prog.compile(
                    use_str=rep.unparse(),
                    file_path=(file_name[:-3] + '.jac'),
                    no_cgen=True
                );
            } except Exception as e {
                return f"Error While Jac to Py AST conversion: {e}";
            }
        } else {
            ir = prog.compile(file_name, no_cgen=True);
        }
        match output {
            case 'sym':
                out = '';
                for module_ in prog.mod.hub.values() {
                    mod_name = module_.name;
                    t = '#' * len(mod_name);
                    out += '##' + t + '##\n# ' + mod_name + ' #\n##' + t + '##\n' + module_.sym_tab.sym_pp() + '\n';
                }
                return out;

            case 'sym.':
                return ir.sym_tab.sym_printgraph()
                if isinstance(ir.sym_tab, UniScopeNode)
                else 'Sym_tab is None.';

            case 'ast':
                out = '';
                for module_ in prog.mod.hub.values() {
                    mod_name = module_.name;
                    t = '#' * len(mod_name);
                    out += '##' + t + '##\n# ' + mod_name + ' #\n##' + t + '##\n' + module_.pp() + '\n';
                }
                return out;

            case 'ast.':
                return ir.printgraph();

            case 'cfg.':
                return cfg_dot_from_file(file_name);

            case 'unparse':
                return ir.unparse();

            case 'pyast':
                ir = prog.compile(file_name);
                return f"{py_ast.dump(ir.gen.py_ast[0], indent=2)}"
                if isinstance(ir.gen.py_ast[0], py_ast.AST)
                else 'Compile failed.';

            case 'docir':
                return str(DocIRGenPass(ir, prog).ir_out.gen.doc_ir);

            case 'py':
                ir = prog.compile(file_name);
                return f"{ir.gen.py}"
                if isinstance(ir.gen.py[0], str)
                else 'Compile failed.';

            case 'esast':
                esast_pass = EsastGenPass(ir, prog);
                es_ir = esast_pass.ir_out;
                es_ast = es_ir.gen.es_ast;
                if isinstance(es_ast, EsNode) {
                    return f"{json.dumps(es_node_to_dict(es_ast), indent=2)}";
                } else {
                    return 'ECMAScript AST generation failed.';
                }

            case 'es':
                esast_pass = EsastGenPass(ir, prog);
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

"""List python ast nodes."""
impl AstTool.py_uni_nodes -> str {
    import from jaclang.compiler.passes.main { PyastBuildPass }
    visit_methods = [
        method
        for method in dir(py_ast._Unparser)
        if method.startswith('visit_')
    ];
    node_names = [method.replace('visit_', '') for method in visit_methods];
    pass_func_names = [];
    for (name, value) in inspect.getmembers(PyastBuildPass) {
        if (name.startswith('proc_') and inspect.isfunction(value)) {
            pass_func_names.append(name.replace('proc_', ''));
        }
    }
    output = '';
    missing = [];
    for i in node_names {
        nd = pascal_to_snake(i);
        this_func = (
            f"def proc_{nd}(self, node: py_ast.{i}) -> ast.UniNode:\n" + '    """Process python node."""\n\n'
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

"""Generate pass template."""
impl AstTool.pass_template -> str {
    output = 'import jaclang.pycore.unitree as ast\nfrom jaclang.pycore.passes import Pass\n\nclass SomePass(Pass):\n';
    """Emit to output.""";
    def emit(to_append: str) -> None {
        nonlocal output ;
        output += '\n    ' + to_append;
    }
    for cls in self.ast_classes {
        emit(f"def exit_{cls.class_name_snake}(self, node: ast.{cls.name}) -> None:");
        emit('    """Sub objects.\n');
        for kid in cls.kids {
            emit(
                f"    {kid.name}: {kid.typ}{(' =' + str(kid.default))
                if kid.default
                else ''},"
            );
        }
        emit('    """\n');
    }
    output = output.replace('jaclang.pycore.unitree.', '').replace('typing.', '').replace(
        "<enum '", ''
    ).replace(
        "'>", ''
    ).replace(
        "<class '", ''
    ).replace(
        "ForwardRef('", ''
    ).replace(
        "')", ''
    );
    return output;
}

"""Initialize."""
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
                cls.__name__ not in [
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
        uni_node_classes, key=lambda cls: Any : source_code.find(f"class {cls.name}")
    );
}

"""Process UniNode class."""
impl UniNodeInfo.process(cls: type[uni.UniNode]) -> None {
    self.name = cls.__name__;
    self.doc = cls.__doc__;
    UniNodeInfo.type_map[self.name] = cls;
    self.class_name_snake = pascal_to_snake(cls.__name__);
    self.init_sig = inspect.signature(cls.__init__);
    self.kids: list[AstKidInfo] = [];
    for (param_name, param) in self.init_sig.parameters.items() {
        if (param_name not in ['self', 'parent', 'kid', 'line', 'sym_tab']) {
            param_type = param.annotation
            if (param.annotation != inspect.Parameter.empty)
            else 'Any';
            param_default = param.default
            if (param.default != inspect.Parameter.empty)
            else None;
            self.kids.append(AstKidInfo(param_name, param_type, param_default));
        }
    }
}

"""Initialize."""
impl UniNodeInfo.postinit -> None {
    self.process(self.cls);
}
