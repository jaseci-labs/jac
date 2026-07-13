import inspect;

def _populate_registry -> object {
    import from jaclang.cli.registry { get_registry, register_feature_commands }
    import jaclang.cli.commands;

    register_feature_commands();
    return get_registry();
}

def _arg_expr(pname: str, param: object) -> str {
    if param.default is inspect.Parameter.empty {
        return f'args["{pname}"]';
    }
    return f'args.get("{pname}", {repr(param.default)})';
}

def generate -> str {
    reg = _populate_registry();
    names = sorted(reg.commands.keys());

    lines: list = [];
    lines.append('"""Auto-generated static command dispatch (#6942 D).');
    lines.append('');
    lines.append('Maps each CLI command name to a direct handler call with');
    lines.append('explicitly forwarded arguments - no Callable field, no **kwargs.');
    lines.append('');
    lines.append('DO NOT EDIT MANUALLY - regenerate with `jac gen-cli-dispatch`.');
    lines.append('"""');
    lines.append('');
    lines.append('def dispatch_command(name: str, args: dict) -> tuple[bool, any] {');

    for cname in names {
        spec = reg.commands[cname];
        handler = spec.handler;
        if handler is None {
            continue;
        }

        module = handler.__module__;
        func = handler.__name__;
        sig = inspect.signature(handler);
        call_args: list = [];
        for (pname, param) in sig.parameters.items() {
            if param.kind in (
                inspect.Parameter.VAR_KEYWORD,
                inspect.Parameter.VAR_POSITIONAL
            ) {
                continue;
            }
            call_args.append(f"{pname}={_arg_expr(pname, param)}");
        }

        joined = ", ".join(call_args);
        lines.append(f"    if name == {repr(cname)} {{");
        lines.append(f"        import from {module} {{ {func} }}");
        lines.append(f"        return (True, {func}({joined}));");
        lines.append('    }');
    }

    lines.append('    return (False, None);');
    lines.append('}');
    return "\n".join(lines) + "\n";
}
