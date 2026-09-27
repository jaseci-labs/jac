import os;

def relative_js_specifier(target_path: str, importer_path: str) -> str {
    target = target_path;
    if target.endswith('.jac') {
        target = target[:-4];
    }

    rel = os.path.relpath(
        os.path.realpath(target), os.path.dirname(os.path.realpath(importer_path))
    );
    rel = rel.replace(os.sep, '/');
    if not rel.startswith('.') {
        rel = './' + rel;
    }
    return rel + '.js';
}

def convert_to_js_import_path(path: str) -> str {
    if not path {
        return path;
    }
    if (path.startswith('./') or path.startswith('../')) {
        return path;
    }
    dot_count = 0;
    for char in path {
        if (char == '.') {
            dot_count += 1;
        } else {
            break;
        }
    }
    common_extensions = (
        '.js',
        '.mjs',
        '.cjs',
        '.css',
        '.scss',
        '.sass',
        '.less',
        '.wasm',
        '.json',
        '.ts',
        '.tsx'
    );
    if (dot_count > 0) {
        rest_of_path = path[dot_count:];
        if ('.' in rest_of_path) {
            last_dot_idx = rest_of_path.rfind('.');
            before_last_dot = rest_of_path[:last_dot_idx];
            after_last_dot = rest_of_path[last_dot_idx:];
            if (after_last_dot in common_extensions) {
                rest_of_path = before_last_dot.replace('.', '/') + after_last_dot;
            } else {
                rest_of_path = rest_of_path.replace('.', '/');
            }
        } else {
            rest_of_path = rest_of_path or '';
        }
        if (dot_count == 1) {
            js_path = ('./' + rest_of_path) if rest_of_path else '.';
        } else {
            parent_dirs = '../' * (dot_count - 1);
            js_path = (parent_dirs[:-1] + ('/' + rest_of_path)) if rest_of_path else '';
        }
        if (js_path in ('.', '..')) {
            return js_path;
        }
        if not js_path.endswith(common_extensions) {
            js_path += '.js';
        }
        return js_path;
    }
    return path;
}
