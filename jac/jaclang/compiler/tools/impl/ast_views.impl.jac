impl module_banner(name: str) -> str {
    rule = "#" * len(name);
    return f"##{rule}##\n# {name} #\n##{rule}##\n";
}

impl parsed_view(module: uni.Module, view: str) -> str {
    if view == "json" {
        return json.dumps(node_to_dict(module), `default=str);
    }
    return print_ast_tree(module);
}

impl client_tree(program: JacProgram, module: uni.Module) -> EsNode {
    require(program, module, CompilationProduct.CLIENT);
    tree = module.gen.es_ast;
    if not isinstance(tree, EsNode) {
        raise KernelError(
            f"no ECMAScript tree was generated for {module.loc.mod_path}"
        );
    }
    return tree;
}

impl analysed_view(program: JacProgram, module: uni.Module, view: str) -> str {
    if view == "sym" {
        return "".join(
            [
                module_banner(each.name)
                    + print_symtab_tree(root_node=each.sym_tab)
                    + "\n"
                for each in program.mod.hub.values()
            ]
        );
    }
    if view == "sym." {
        return printgraph_symtab_tree(module.sym_tab);
    }
    if view == "ast" {
        return "".join(
            [
                module_banner(each.name) + print_ast_tree(each) + "\n"
                for each in program.mod.hub.values()
            ]
        );
    }
    if view == "ast." {
        return printgraph_ast_tree(module);
    }
    if view == "cfg." {
        return cfg_dot_text(program, module);
    }
    if view == "unparse" {
        return unparse_module(module);
    }
    if view == "docir" {
        return str(run_utility(CompilationProduct.DOC, module, program).module.gen.doc_ir);
    }
    if view == "esast" {
        return json.dumps(es_node_to_dict(client_tree(program, module)), indent=2);
    }
    if view == "es" {
        return es_to_js(client_tree(program, module));
    }
    raise KernelError(f"unknown AST view '{view}'");
}
