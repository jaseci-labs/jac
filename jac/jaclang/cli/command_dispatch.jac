"""Auto-generated static command dispatch (#6942 D).

Maps each CLI command name to a direct handler call with
explicitly forwarded arguments - no Callable field, no **kwargs.

DO NOT EDIT MANUALLY - regenerate with `jac gen-cli-dispatch`.
"""

"""Normalize a handler return value into a process exit code."""
def _norm_exit(result: any) -> int {
    if result is None {
        return 0;
    } elif isinstance(result, int) {
        return result;
    } else {
        return 0;
    }
}

"""Dispatch a CLI command; return its exit code, or None if unknown."""
def dispatch_command(name: str, args: dict) -> int | None {
    if name == 'ai' {
        import from jaclang.cli.commands.ai { ai }
        return _norm_exit(
            ai(
                prompt=args.get("prompt", ''),
                model=args.get("model", ''),
                n_ctx=args.get("n_ctx", 0),
                safe=args.get("safe", False),
                quiet=args.get("quiet", False),
                ui=args.get("ui", False)
            )
        );
    }
    if name == 'browse' {
        import from jaclang.cli.commands.browse { browse }
        return _norm_exit(
            browse(
                action=args["action"],
                args=args.get("args", []),
                session=args.get("session", 'default'),
                viewport=args.get("viewport", '1280x720')
            )
        );
    }
    if name == 'build' {
        import from jaclang.cli.commands.build { build }
        return _norm_exit(
            build(
                filename=args.get("filename", ''),
                projection=args.get("projection", 'jab'),
                output=args.get("output", 'dist'),
                no_typecheck=args.get("no_typecheck", False),
                check_only=args.get("check_only", False),
                client=args.get("client", ''),
                platform=args.get("platform", None)
            )
        );
    }
    if name == 'check' {
        import from jaclang.cli.commands.analysis { check }
        return _norm_exit(
            check(
                paths=args["paths"],
                print_errs=args.get("print_errs", True),
                ignore=args.get("ignore", None),
                disable_error_code=args.get("disable_error_code", None),
                parse_only=args.get("parse_only", False),
                nowarn=args.get("nowarn", False),
                lint_only=args.get("lint_only", False),
                fix=args.get("fix", False)
            )
        );
    }
    if name == 'clean' {
        import from jaclang.cli.commands.project { clean }
        return _norm_exit(
            clean(
                all=args.get("all", False),
                data=args.get("data", False),
                cache=args.get("cache", False),
                packages=args.get("packages", False),
                force=args.get("force", False)
            )
        );
    }
    if name == 'code' {
        import from jaclang.cli.commands.code { code }
        return _norm_exit(
            code(
                action=args.get("action", ''),
                target=args.get("target", ''),
                text=args.get("text", False),
                depth=args.get("depth", 1)
            )
        );
    }
    if name == 'completions' {
        import from jaclang.cli.commands.tools { completions }
        return _norm_exit(
            completions(shell=args.get("shell", 'bash'), install=args.get("install", False)))
        );
    }
    if name == 'config' {
        import from jaclang.cli.commands.config { config }
        return _norm_exit(
            config(
                action=args.get("action", 'show'),
                key=args.get("key", ''),
                value=args.get("value", ''),
                group=args.get("group", ''),
                output=args.get("output", 'table')
            )
        );
    }
    if name == 'create' {
        import from jaclang.cli.commands.project { create }
        return _norm_exit(
            create(
                name=args.get("name", ''),
                force=args.get("force", False),
                kind=args.get("kind", ''),
                use=args.get("use", 'default'),
                list=args.get("list", False),
                pack=args.get("pack", ''),
                pack_output=args.get("pack_output", ''),
                skip=args.get("skip", False),
                style=args.get("style", None),
                baseColor=args.get("baseColor", None),
                theme=args.get("theme", None),
                font=args.get("font", None),
                radius=args.get("radius", None),
                menuAccent=args.get("menuAccent", None),
                menuColor=args.get("menuColor", None)
            )
        );
    }
    if name == 'db' {
        import from jaclang.cli.commands.db { db }
        return _norm_exit(
            db(
                action=args.get("action", 'inspect'),
                sub=args.get("sub", ''),
                arg1=args.get("arg1", ''),
                arg2=args.get("arg2", ''),
                limit=args.get("limit", 50),
                app=args.get("app", '')
            )
        );
    }
    if name == 'dev' {
        import from jaclang.cli.commands.execution { dev }
        return _norm_exit(
            dev(
                filename=args.get("filename", ''),
                port=args.get("port", 8000),
                api_port=args.get("api_port", 0)
            )
        );
    }
    if name == 'dot' {
        import from jaclang.cli.commands.tools { dot }
        return _norm_exit(
            dot(
                filename=args["filename"],
                session=args.get("session", ''),
                initial=args.get("initial", ''),
                depth=args.get("depth", -1),
                traverse=args.get("traverse", False),
                connection=args.get("connection", []),
                bfs=args.get("bfs", False),
                edge_limit=args.get("edge_limit", 512),
                node_limit=args.get("node_limit", 512),
                saveto=args.get("saveto", ''),
                to_screen=args.get("to_screen", False),
                format=args.get("format", 'dot')
            )
        );
    }
    if name == 'fmt' {
        import from jaclang.cli.commands.analysis { format }
        return _norm_exit(
            format(
                paths=args["paths"],
                to_screen=args.get("to_screen", False),
                lintfix=args.get("lintfix", False),
                check=args.get("check", False)
            )
        );
    }
    if name == 'gen-cli-dispatch' {
        import from jaclang.cli.commands.tools { gen_cli_dispatch }
        return _norm_exit(gen_cli_dispatch(verify=args.get("verify", False)));
    }
    if name == 'gen-jir-registry' {
        import from jaclang.cli.commands.tools { gen_jir_registry }
        return _norm_exit(gen_jir_registry(verify=args.get("verify", False)));
    }
    if name == 'gen-uni-dispatch' {
        import from jaclang.cli.commands.tools { gen_uni_dispatch }
        return _norm_exit(gen_uni_dispatch(verify=args.get("verify", False)));
    }
    if name == 'gen_parser' {
        import from jaclang.cli.commands.analysis { gen_parser }
        return _norm_exit(gen_parser());
    }
    if name == 'guide' {
        import from jaclang.cli.commands.guide { guide }
        return _norm_exit(
            guide(
                topic=args.get("topic", ''),
                search=args.get("search", ''),
                export=args.get("export", ''),
                as_json=args.get("as_json", False)
            )
        );
    }
    if name == 'install' {
        import from jaclang.cli.commands.project { install }
        return _norm_exit(
            install(
                packages=args.get("packages", []),
                editable=args.get("editable", []),
                dev=args.get("dev", False),
                extras=args.get("extras", []),
                no_save=args.get("no_save", False),
                git=args.get("git", ''),
                npm=args.get("npm", False),
                shadcn=args.get("shadcn", False),
                verbose=args.get("verbose", False),
                force_reinstall=args.get("force_reinstall", False),
                no_cache_dir=args.get("no_cache_dir", False),
                pre=args.get("pre", False),
                dry_run=args.get("dry_run", False),
                no_deps=args.get("no_deps", False),
                quiet=args.get("quiet", False),
                prefer_binary=args.get("prefer_binary", False),
                install_global=args.get("install_global", False),
                scale=args.get("scale", False),
                plan=args.get("plan", False),
                as_json=args.get("as_json", False)
            )
        );
    }
    if name == 'lsp' {
        import from jaclang.cli.commands.tools { lsp }
        return _norm_exit(lsp());
    }
    if name == 'mcp' {
        import from jaclang.cli.commands.mcp { mcp_cmd }
        return _norm_exit(
            mcp_cmd(
                transport=args.get("transport", 'stdio'),
                port=args.get("port", 3001),
                host=args.get("host", '127.0.0.1'),
                mode=args.get("mode", ''),
                inspect=args.get("inspect", False)
            )
        );
    }
    if name == 'model' {
        import from jaclang.byllm.cli { model }
        return _norm_exit(model(action=args.get("action", 'list'), alias=args.get("alias", '')));
    }
    if name == 'nacompile' {
        import from jaclang.cli.commands.nacompile { nacompile }
        return _norm_exit(
            nacompile(
                filename=args["filename"],
                output=args.get("output", ''),
                scrub=args.get("scrub", False),
                target=args.get("target", ''),
                shared=args.get("shared", False),
                debug=args.get("debug", False),
                gc=args.get("gc", 'cycles')
            )
        );
    }
    if name == 'ninja' {
        import from jaclang.cli.commands.tools { ninja }
        return _norm_exit(ninja());
    }
    if name == 'precommit' {
        import from jaclang.cli.commands.analysis { precommit }
        return _norm_exit(
            precommit(
                paths=args.get("paths", None),
                staged=args.get("staged", False),
                verify=args.get("verify", False),
                install=args.get("install", False),
                force=args.get("force", False)
            )
        );
    }
    if name == 'remove' {
        import from jaclang.cli.commands.project { remove }
        return _norm_exit(
            remove(
                packages=args.get("packages", []),
                dev=args.get("dev", False),
                npm=args.get("npm", False),
                shadcn=args.get("shadcn", False)
            )
        );
    }
    if name == 'retheme' {
        import from jaclang.cli.shadcn.cli { retheme }
        return _norm_exit(
            retheme(
                style=args.get("style", None),
                baseColor=args.get("baseColor", None),
                theme=args.get("theme", None),
                font=args.get("font", None),
                radius=args.get("radius", None),
                menuAccent=args.get("menuAccent", None),
                menuColor=args.get("menuColor", None)
            )
        );
    }
    if name == 'run' {
        import from jaclang.cli.commands.execution { run }
        return _norm_exit(
            run(
                filename=args.get("filename", ''),
                show=args.get("show", False),
                main=args.get("main", True),
                cache=args.get("cache", True),
                autonative=args.get("autonative", False),
                diagnostics=args.get("diagnostics", ''),
                entry_name=args.get("entry_name", ''),
                nd=args.get("nd", ''),
                root_id=args.get("root_id", ''),
                debug_mode=args.get("debug_mode", False),
                args=args.get("args", [])
            )
        );
    }
    if name == 'scale' {
        import from jaclang.scale.plugin { scale_cmd }
        return _norm_exit(
            scale_cmd(
                action=args["action"],
                service_name=args.get("service_name", ''),
                lines=args.get("lines", 50),
                target=args.get("target", 'kubernetes'),
                component=args.get("component", '')
            )
        );
    }
    if name == 'setup' {
        import from jaclang.runtimelib.client.cli { setup }
        return _norm_exit(setup(target=args["target"], platform=args.get("platform", None)));
    }
    if name == 'start' {
        import from jaclang.cli.commands.execution { start }
        return _norm_exit(
            start(
                filename=args["filename"],
                port=args.get("port", 8000),
                main=args.get("main", True),
                faux=args.get("faux", False),
                dev=args.get("dev", False),
                api_port=args.get("api_port", 0),
                no_client=args.get("no_client", False),
                client=args.get("client", 'web'),
                host=args.get("host", ''),
                platform=args.get("platform", 'auto'),
                scale=args.get("scale", False),
                target=args.get("target", 'kubernetes'),
                enable_tls=args.get("enable_tls", False),
                dry_run=args.get("dry_run", False),
                show_yaml=args.get("show_yaml", False)
            )
        );
    }
    if name == 'test' {
        import from jaclang.cli.commands.analysis { test }
        return _norm_exit(
            test(
                paths=args.get("paths", []),
                test_name=args.get("test_name", ''),
                filter=args.get("filter", ''),
                xit=args.get("xit", False),
                maxfail=args.get("maxfail", None),
                directory=args.get("directory", ''),
                verbose=args.get("verbose", False),
                ignore=args.get("ignore", '')
            )
        );
    }
    if name == 'tool' {
        import from jaclang.cli.commands.tools { tool }
        return _norm_exit(tool(tool=args["tool"], args=args.get("args", [])));
    }
    if name == 'update' {
        import from jaclang.cli.commands.project { update }
        return _norm_exit(
            update(
                packages=args.get("packages", []),
                dev=args.get("dev", False),
                verbose=args.get("verbose", False)
            )
        );
    }
    if name == 'x' {
        import from jaclang.cli.commands.execution { x }
        return _norm_exit(
            x(
                name=args.get("name", ''),
                use_global=args.get("use_global", False),
                use_node=args.get("use_node", False),
                list_tools=args.get("list_tools", False),
                args=args.get("args", [])
            )
        );
    }
    return None;
}
