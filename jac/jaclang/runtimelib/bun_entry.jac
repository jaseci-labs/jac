def build_bun_server_entry_script(
    project_name: str,
    walkers: list,
    functions: list,
    module_imports: list[str],
    handler_imports: list[str]
) -> str {
    walker_names: list[str] = [];
    for w in walkers {
        walker_names.append(str(w['name']));
    }
    func_names: list[str] = [];
    for f in functions {
        func_names.append(str(f['name']));
    }
    walker_lit = '[' + ', '.join([repr(n) for n in walker_names]) + ']';
    func_lit = '[' + ', '.join([repr(n) for n in func_names]) + ']';

    lines: list[str] = [
        f'// Auto-generated Bun server entry for {project_name!r}',
        'import { startBunServer } from "./server_runtime.js";'
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
        wn = str(w['name']);
        lines.append(f'    {repr(wn)}: _W_{wn},');
    }
    lines.append('  },');
    lines.append('  functions: {');
    for f in functions {
        fn = str(f['name']);
        lines.append(f'    {repr(fn)}: _F_{fn},');
    }
    lines.extend(
        [
            '  },',
            '  restspec: ['
        ]
    );
    rest_triples: list[str] = [];
    for f in functions {
        fn = str(f['name']);
        rest_triples.append(
            '{ fn: _F_' + fn + ', handler: _F_' + fn + ', name: ' + repr(fn) + ' }'
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
            '  port,',
            '});',
            ''
        ]
    );
    return '\n'.join(lines);
}
