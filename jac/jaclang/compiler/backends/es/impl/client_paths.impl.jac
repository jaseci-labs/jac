impl jac_js_path(path: str) -> str {
    path = path.replace('\\', '/');
    if path.endswith('.native.jac') {
        return path[:-len('.native.jac')] + '.js';
    }
    if path.endswith('.jac') {
        import from jaclang.compiler.frontend.host { active_host }
        stem = active_host().path_facts(path).module_stem;
        return os.path.join(os.path.dirname(path), stem + '.js').replace(os.sep, '/');
    }
    return path;
}

impl client_output_path(source_path: str, source_root: str) -> str {
    source = os.path.realpath(source_path);
    root_path = os.path.realpath(source_root);
    relative = '';
    try {
        relative = os.path.relpath(source, root_path).replace(os.sep, '/');
    } except ValueError {
        relative = '';
    }
    if not relative or relative == '..' or relative.startswith('../') {
        import from jaclang.compiler.frontend.host { active_host }
        runtime = active_host().jac_virtual_module_path('@jac/runtime');
        if runtime {
            runtime_relative = '..';
            try {
                runtime_relative = os.path.relpath(
                    source, os.path.dirname(os.path.realpath(runtime))
                ).replace(
                    os.sep, '/'
                );
            } except ValueError {}

            if runtime_relative != '..' and not runtime_relative.startswith('../') {
                return jac_js_path(runtime_relative);
            }
        }
        if relative {
            parts = relative.split('/');
            depth = 0;
            while depth < len(parts) and parts[depth] == '..' {
                depth += 1;
            }
            relative = '__jac_external__/up'
                + str(depth)
                + '/'
                + '/'.join(parts[depth:]);
        } else {
            tail = source.replace(os.sep, '/');
            anchor = 'root';
            if len(tail) > 1 and tail[1] == ':' {
                anchor = 'drive/' + tail[0];
                tail = tail[2:];
            } elif tail.startswith('//') {
                anchor = 'unc';
            }
            relative = '__jac_external__/source/' + anchor + '/' + tail.lstrip('/');
        }
    } elif relative.split('/')[0] == '__jac_external__' {
        relative = '__jac_external__/project/' + relative;
    }
    return jac_js_path(relative);
}

impl relative_js_specifier(
    target_path: str, importer_path: str, source_root: str = ""
) -> str {
    target = client_output_path(target_path, source_root)
        if source_root
        else jac_js_path(os.path.realpath(target_path));
    importer = client_output_path(importer_path, source_root)
        if source_root
        else os.path.realpath(importer_path);

    rel = os.path.relpath(target, os.path.dirname(importer) or '.');
    rel = rel.replace(os.sep, '/');
    if not rel.startswith('.') {
        rel = './' + rel;
    }
    return rel;
}
