obj EndpointMeta {
    has name: str,
        module: str,
        `pub: bool = False,
        params: list[str] = [];

    def postinit {
        if not self.name {
            raise ValueError('EndpointMeta requires a name');
        }
    }
}


def build_bun_server_entry_script(
    project_name: str,
    walkers: list[EndpointMeta],
    functions: list[EndpointMeta],
    module_imports: list[str],
    handler_imports: list[str]
) -> str {
    walker_names: list[str] = [w.name for w in walkers];
    func_names: list[str] = [f.name for f in functions];

    walker_lit = '[' + ', '.join([repr(n) for n in walker_names]) + ']';
    func_lit = '[' + ', '.join([repr(n) for n in func_names]) + ']';
    params_pairs: list[str] = [];
    for f in functions {
        if f.params {
            params_pairs.append(
                f"{repr(f.name)}: [{', '.join([repr(p) for p in f.params])}]"
            );
        }
    }
    params_lit = '{' + ', '.join(params_pairs) + '}';

    lines: list[str] = [
        f'// Auto-generated Bun server entry for {project_name!r}',
        'import { execWalker, startBunServer } from "./server_runtime.js";',
        'import { _jac } from "./jac_runtime.js";',
        'globalThis._jac = _jac;'
    ];
    for imp in module_imports {
        lines.append(imp);
    }
    for imp in handler_imports {
        lines.append(imp);
    }
    lines.extend(
        [
            '',
            'const port = Number(process.env.PORT || process.env.JAC_PORT || "8000");',
            'const handlers = {',
            '  walkers: {'
        ]
    );
    for w in walkers {
        lines.append(f'    {repr(w.name)}: _spawn_{w.name},');
    }
    lines.append('  },');
    lines.append('  functions: {');
    for f in functions {
        lines.append(f'    {repr(f.name)}: _F_{f.name},');
    }
    lines.extend(['  },', '  restspec: [']);
    rest_triples: list[str] = [];
    for f in functions {
        rest_triples.append(
            '{ fn: _F_'
                + f.name
                + ', handler: _F_'
                + f.name
                + ', name: '
                + repr(f.name)
                + ' }'
        );
    }
    if rest_triples {
        lines.append('    ' + ',\n    '.join(rest_triples));
    }
    lines.extend(
        [
            '  ]',
            '};',
            '',
            'startBunServer({',
            f'  project: {repr(project_name)},',
            f'  walkers: {walker_lit},',
            f'  functions: {func_lit},',
            '  handlers,',
            f'  params: {params_lit},',
            '  port,',
            '});',
            ''
        ]
    );
    return '\n'.join(lines);
}
