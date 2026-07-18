"""c2jac project mode: multi-TU lift with a cross-TU symbol registry.

Mirrors jac2c's whole-program shape on the ingest side: index defined symbols,
lift each translation unit, then wire `import from <stem> { ... }` for foreign
calls so lifted modules can call each other.
"""

import os;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.compiler.cfront.lift {
    LiftResult,
    lift_c_file,
    render_lifted_jac
}
import from jaclang.compiler.cfront.report {
    C2JacReport,
    build_c2jac_report,
    write_c2jac_report,
    write_project_report
}
import from jaclang.vendor.pycparser { c_ast, c_parser }

obj ProjectLiftResult {
    has files: list[C2JacReport] = [],
        outputs: list[str] = [],
        aggregate_path: str = "",
        registry: dict[str, str] = {};
}

def _stem(path: str) -> str {
    base = os.path.basename(path);
    if base.endswith(".c") {
        return base[: -2];
    }
    if base.endswith(".i") {
        return base[: -2];
    }
    return os.path.splitext(base)[0];
}

def _name(src: uni.Source, value: str) -> uni.Name {
    return uni.Name(
        orig_src=src,
        name=Tok.NAME,
        value=value,
        line=0,
        end_line=0,
        col_start=0,
        col_end=max(len(value), 1),
        pos_start=0,
        pos_end=max(len(value), 1)
    );
}

def _make_import(src: uni.Source, mod_stem: str, names: list[str]) -> uni.Import {
    path_name = _name(src, mod_stem);
    path = uni.ModulePath(path=[path_name], level=0, alias=None, kid=[path_name]);
    items: list[uni.ModuleItem] = [];
    for n in names {
        ni = _name(src, n);
        items.append(uni.ModuleItem(name=ni, alias=None, kid=[ni]));
    }
    kid: list[uni.UniNode] = [path, *items];
    return uni.Import(from_loc=path, items=items, is_absorb=False, kid=kid);
}

def _collect_c_defs(file_ast: object, stem: str, registry: dict[str, str]) {
    # First-wins: the first defining TU owns the symbol.
    for entry in (file_ast?.ext or []) {
        if isinstance(entry, c_ast.FuncDef) and entry.decl and entry.decl.name {
            nm = entry.decl.name;
            if nm not in registry {
                registry[nm] = stem;
            }
        }
        if isinstance(entry, c_ast.Decl) and entry.type is not None {
            t = entry.type;
            if isinstance(t, c_ast.Struct) and t.name and t.decls is not None {
                if t.name not in registry {
                    registry[t.name] = stem;
                }
            }
            if isinstance(t, c_ast.TypeDecl) and isinstance(t.type, c_ast.Struct) {
                s = t.type;
                if s.name and s.decls is not None and s.name not in registry {
                    registry[s.name] = stem;
                }
            }
        }
        if isinstance(entry, c_ast.Typedef) and entry.name {
            if entry.name not in registry {
                registry[entry.name] = stem;
            }
        }
    }
}

def _parse_preprocessed(
    filename: str,
    include_dirs: list[str] | None,
    defines: list[str] | None,
    undefines: list[str] | None,
    force_includes: list[str] | None,
    nostdinc: bool
) -> object {
    c_src = read_file_with_encoding(filename);
    if not filename.endswith(".i") {
        import from jaclang.compiler.cfront.preprocess { preprocess_c }
        c_src = preprocess_c(
            c_src,
            filename,
            include_dirs=include_dirs,
            defines=defines,
            undefines=undefines,
            force_includes=force_includes,
            nostdinc=nostdinc
        );
    }
    return c_parser.CParser().parse(c_src, filename);
}

def discover_c_sources(src_dir: str) -> list[str] {
    out: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(src_dir) {
        for fn in sorted(files) {
            if fn.endswith(".c") {
                out.append(os.path.join(dirpath, fn));
            }
        }
    }
    return out;
}

def _local_ability_names(mod: uni.Module) -> set[str] {
    names: set[str] = set();
    for ab in mod.get_all_sub_nodes(typ=uni.Ability) {
        if isinstance(ab.name_ref, uni.Name) {
            names.add(ab.name_ref.value);
        }
    }
    return names;
}

def wire_cross_tu_imports(mod: uni.Module, my_stem: str, registry: dict[str, str]) {
    local_fns = _local_ability_names(mod);
    needed: dict[str, list[str]] = {};
    for call in mod.get_all_sub_nodes(typ=uni.FuncCall) {
        if not isinstance(call.target, uni.Name) {
            continue;
        }
        sym = call.target.value;
        owner = registry.get(sym);
        if owner is None or owner == my_stem or sym in local_fns {
            continue;
        }
        bucket = needed.setdefault(owner, []);
        if sym not in bucket {
            bucket.append(sym);
        }
    }
    # Strip duplicate archetypes owned by another TU (shared-header first-wins).
    new_body: list[uni.ElementStmt | uni.String | uni.EmptyToken] = [];
    for el in list(mod.body) {
        if isinstance(el, uni.Archetype) {
            owner = registry.get(el.name.value);
            if owner is not None and owner != my_stem {
                bucket = needed.setdefault(owner, []);
                if el.name.value not in bucket {
                    bucket.append(el.name.value);
                }
                continue;
            }
        }
        new_body.append(el);
    }
    if not needed {
        mod.body = new_body;
        mod.kid = list(new_body);
        return;
    }
    imports: list[uni.ElementStmt] = [];
    for owner in sorted(needed.keys()) {
        imports.append(_make_import(mod.source, owner, sorted(needed[owner])));
    }
    wired = [*imports, *new_body];
    mod.body = wired;
    mod.kid = list(wired);
}

def lift_c_project(
    src_dir: str,
    out_dir: str,
    include_dirs: list[str] | None = None,
    defines: list[str] | None = None,
    undefines: list[str] | None = None,
    force_includes: list[str] | None = None,
    nostdinc: bool = False,
    lenient_c: bool = True
) -> ProjectLiftResult {
    sources = discover_c_sources(src_dir);
    if not sources {
        raise ValueError(f"no .c files under {src_dir}");
    }
    registry: dict[str, str] = {};
    for path in sources {
        stem = _stem(path);
        file_ast = _parse_preprocessed(
            path, include_dirs, defines, undefines, force_includes, nostdinc
        );
        _collect_c_defs(file_ast, stem, registry);
    }
    os.makedirs(out_dir, exist_ok=True);
    reports: list[C2JacReport] = [];
    outputs: list[str] = [];
    for path in sources {
        stem = _stem(path);
        res = lift_c_file(
            path,
            include_dirs=include_dirs,
            defines=defines,
            undefines=undefines,
            force_includes=force_includes,
            nostdinc=nostdinc,
            lenient_c=lenient_c
        );
        wire_cross_tu_imports(res.module, stem, registry);
        jac_path = os.path.join(out_dir, stem + ".jac");
        jac_str = render_lifted_jac(res);
        with open(jac_path, "w", encoding="utf-8") as f {
            f.write(jac_str);
        }
        rep = build_c2jac_report(
            source=path,
            output=jac_path,
            sites=res.sites,
            quarantined=res.quarantined_functions,
            lenient=lenient_c
        );
        write_c2jac_report(jac_path, rep);
        reports.append(rep);
        outputs.append(jac_path);
    }
    agg = write_project_report(out_dir, reports);
    return ProjectLiftResult(
        files=reports, outputs=outputs, aggregate_path=agg, registry=registry
    );
}
