glob _GROUPING_AT_RULES: set[str] = {
         'media',
         'supports',
         'container',
         'layer',
         'scope'
     };

impl ScopedStyleSheet.postinit -> None {
    self.scoped_css = scope_stylesheet(
        self.source_css, self.module_path, self.class_map
    );
}

impl ScopedStyleSheet.rewrite_class_value(value: str) -> str {
    tokens = value.split();
    if not tokens {
        return value;
    }
    rewritten = [self.class_map.get(tok, tok) for tok in tokens];
    return ' '.join(rewritten);
}

impl hash_class_name(module_path: str, class_name: str) -> str {
    digest = blake2s((module_path + '::' + class_name).encode('utf-8')).hexdigest();
    return f"{class_name}-{digest[:8]}";
}

impl _skip_string(s: str, i: int) -> int {
    quote = s[i];
    n = len(s);
    j = i + 1;
    while (j < n) {
        if (s[j] == '\\') {
            j += 2;
            continue;
        }
        if (s[j] == quote) {
            return j + 1;
        }
        j += 1;
    }
    return n;
}

impl _consume_braced_block(css: str, start: int) -> tuple[(str, int)] {
    depth = 0;
    i = start;
    n = len(css);
    while (i < n) {
        if (css[i:i + 2] == '/*') {
            close = css.find('*/', i + 2);
            i = n if (close == -1) else (close + 2);
            continue;
        }
        ch = css[i];
        if (ch == '"' or ch == "'") {
            i = _skip_string(css, i);
            continue;
        }
        if (ch == '{') {
            depth += 1;
        } elif (ch == '}') {
            depth -= 1;
            if (depth == 0) {
                return (css[start:i + 1], i + 1);
            }
        }
        i += 1;
    }
    return (css[start:n], n);
}

impl _grouping_at_rule(prelude: str) -> bool {
    text = prelude.strip();
    if not text.startswith('@') {
        return False;
    }
    name = '';
    for ch in text[1:] {
        if (ch.isalnum() or ch == '-') {
            name += ch;
        } else {
            break;
        }
    }
    return name.lower() in _GROUPING_AT_RULES;
}

impl scope_selector(selector: str, module_path: str, class_map: dict[str, str]) -> str {
    out: list[str] = [];
    i = 0;
    n = len(selector);
    while (i < n) {
        if (selector[i:i + 2] == '/*') {
            close = selector.find('*/', i + 2);
            end = n if (close == -1) else (close + 2);
            out.append(selector[i:end]);
            i = end;
            continue;
        }
        ch = selector[i];
        if (ch == '"' or ch == "'") {
            end = _skip_string(selector, i);
            out.append(selector[i:end]);
            i = end;
            continue;
        }
        if (ch == '[') {
            close = selector.find(']', i);
            end = n if (close == -1) else (close + 1);
            out.append(selector[i:end]);
            i = end;
            continue;
        }

        if (selector[i:i + 8] == ':global(') {
            depth = 1;
            j = i + 8;
            while (j < n and depth > 0) {
                if (selector[j] == '(') {
                    depth += 1;
                } elif (selector[j] == ')') {
                    depth -= 1;
                    if (depth == 0) {
                        break;
                    }
                }
                j += 1;
            }
            out.append(selector[i + 8:j]);
            i = (j + 1) if (j < n) else n;
            continue;
        }

        if (
            ch == '.'
            and (i + 1) < n
            and (selector[i + 1].isalpha() or selector[i + 1] in '_-')
        ) {
            k = i + 1;
            while (k < n and (selector[k].isalnum() or selector[k] in '_-')) {
                k += 1;
            }
            name = selector[i + 1:k];
            hashed = class_map.get(name);
            if (hashed is None) {
                hashed = hash_class_name(module_path, name);
                class_map[name] = hashed;
            }
            out.append('.' + hashed);
            i = k;
            continue;
        }
        out.append(ch);
        i += 1;
    }
    return ''.join(out);
}

impl scope_stylesheet(css: str, module_path: str, class_map: dict[str, str]) -> str {
    out: list[str] = [];
    prelude: list[str] = [];
    i = 0;
    n = len(css);
    while (i < n) {
        if (css[i:i + 2] == '/*') {
            close = css.find('*/', i + 2);
            end = n if (close == -1) else (close + 2);
            prelude.append(css[i:end]);
            i = end;
            continue;
        }
        ch = css[i];
        if (ch == '"' or ch == "'") {
            end = _skip_string(css, i);
            prelude.append(css[i:end]);
            i = end;
            continue;
        }
        if (ch == '{') {
            sel = ''.join(prelude);
            prelude = [];
            if _grouping_at_rule(sel) {
                out.append(sel);
                out.append('{');
                i += 1;
                continue;
            }

            if sel.strip().startswith('@') {
                out.append(sel);
            } else {
                out.append(scope_selector(sel, module_path, class_map));
            }
            (block, after) = _consume_braced_block(css, i);
            out.append(block);
            i = after;
            continue;
        }
        if (ch == '}') {
            out.append(''.join(prelude));
            prelude = [];
            out.append('}');
            i += 1;
            continue;
        }
        if (ch == ';') {
            out.append(''.join(prelude));
            prelude = [];
            out.append(';');
            i += 1;
            continue;
        }
        prelude.append(ch);
        i += 1;
    }
    out.append(''.join(prelude));
    return ''.join(out);
}

impl load_style_annex(module_path: str) -> (ScopedStyleSheet | None) {
    css_path = discover_style_annex(module_path);
    if (css_path is None) {
        return None;
    }
    try {
        with open(css_path, 'r', encoding='utf-8') as f {
            source = f.read();
        }
    } except OSError {
        return None;
    }
    return ScopedStyleSheet(
        module_path=module_path, css_path=css_path, source_css=source
    );
}
