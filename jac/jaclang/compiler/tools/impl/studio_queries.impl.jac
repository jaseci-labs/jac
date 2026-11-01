impl node_text(nd: any) -> str {
    if nd is None {
        return "";
    }
    return " ".join(unparse_node(nd).split());
}

impl source_text(nd: any) -> str {
    loc = nd.loc;
    raw = loc.orig_src.code.encode("utf-8")[loc.pos_start:loc.pos_end];
    return " ".join(raw.decode("utf-8", errors="replace").split());
}

impl doc_text(nd: any) -> str {
    doc = nd.doc if isinstance(nd, uni.AstDocNode) else None;
    if doc is None {
        return "";
    }
    return str(doc.lit_value).strip();
}

impl lines_text(lines: list[str], first: int, last: int) -> str {
    return "\n".join([ln.rstrip() for ln in lines[max(first - 1, 0):max(last, 0)]]);
}

impl span_into(row: OutlineSymbol, nd: uni.UniNode) {
    row.file = os.path.realpath(nd.loc.mod_path);
    row.line = nd.loc.first_line;
    row.end_line = nd.loc.last_line;
    row.col = nd.loc.col_start;
}

impl ability_symbol(ab: uni.Ability, owner: str) -> OutlineSymbol {
    name = ab.name_ref.sym_name if ab.name_ref else "?";
    sig = ab.signature;
    sig_text = "";
    event = "";
    if isinstance(sig, uni.EventSignature) {
        event = node_text(sig.arch_tag_info);
        sig_text = f"with {event} {sig.event.value}".strip();
    } elif isinstance(sig, uni.FuncSignature) {
        sig_text = source_text(sig) or node_text(sig);
    }
    kind = "method" if owner else "def";
    if event or isinstance(sig, uni.EventSignature) {
        kind = "can";
    }
    row = OutlineSymbol(
        kind=kind,
        name=name,
        owner=owner,
        signature=sig_text,
        event=event,
        doc=doc_text(ab)
    );
    span_into(row, ab);
    return row;
}

impl outline_rows(tree: uni.Module, out: ModuleOutline) {
    out.doc = doc_text(tree);
    for el in tree.body {
        if isinstance(el, uni.Archetype) {
            name = el.name.sym_name;
            arch = OutlineSymbol(
                kind=el.arch_type.value,
                name=name,
                bases=[node_text(b) for b in (el.base_classes or [])],
                doc=doc_text(el)
            );
            span_into(arch, el);
            out.symbols.append(arch);
            for hv in el.get_has_vars() {
                field = OutlineSymbol(
                    kind="has",
                    name=hv.name.sym_name,
                    owner=name,
                    type_str=node_text(hv.type_tag.tag if hv.type_tag else None)
                );
                span_into(field, hv);
                out.symbols.append(field);
            }
            for ab in el.get_methods() {
                if ab.name_ref is not None {
                    out.symbols.append(ability_symbol(ab, name));
                }
            }
        } elif isinstance(el, uni.Enum) {
            row = OutlineSymbol(
                kind="enum",
                name=el.name.sym_name,
                bases=[node_text(b) for b in (el.base_classes or [])],
                doc=doc_text(el)
            );
            span_into(row, el);
            out.symbols.append(row);
        } elif isinstance(el, uni.Ability) and el.name_ref is not None {
            out.symbols.append(ability_symbol(el, ""));
        }
    }
    for idef in tree.get_all_sub_nodes(uni.ImplDef) {
        parts = [t.sym_name for t in idef.target];
        if not parts {
            continue;
        }
        target = ".".join(parts);
        row = OutlineSymbol(kind="impl", name=target, target=target);
        span_into(row, idef);
        out.symbols.append(row);
    }
    for row in out.symbols {
        if row.file and row.file not in out.files {
            out.files.append(row.file);
        }
    }
}

impl module_outline_of(host: ProjectHost, path: str) -> ModuleOutline {
    real = os.path.realpath(path);
    out = ModuleOutline(path=real, files=[real]);
    tree = host.woven_module(real, None);
    if tree is None {
        (plain, failed) = parse(host.read_source(real), real);
        if failed {
            out.error = "could not parse: syntax errors";
            return out;
        }
        for annex in annex_sources(real) {
            (extra, _) = parse(annex.source, annex.path);
            merge_annex_into(plain, extra);
        }
        tree = plain;
    }
    outline_rows(tree, out);
    return out;
}

impl edit_symbol_rows(text: str, path: str) -> list[EditSymbol] {
    rows: list[EditSymbol] = [];
    if not text.strip() {
        return rows;
    }
    (module, had_error) = parse_woven(text, path, None, [], load_kernel=False);
    lines = text.splitlines();
    taken: set[str] = set();
    def put(key: str, kind: str, nd: any, sig: str) {
        first = nd.loc.first_line;
        last = nd.loc.last_line;
        k = key;
        n = 2;
        while k in taken {
            k = f"{key}#{n}";
            n += 1;
        }
        taken.add(k);
        rows.append(
            EditSymbol(
                key=k,
                kind=kind,
                line=first,
                end_line=last,
                text=lines_text(lines, first, last),
                signature=sig
            )
        );
    }
    for el in module.body {
        if isinstance(el, uni.Archetype) {
            name = el.name.sym_name;
            kind = el.arch_type.value;
            member_spans: list[tuple[int, int]] = [];
            fields: list[str] = [];
            for hv in el.get_has_vars() {
                fname = hv.name.sym_name;
                ftype = node_text(hv.type_tag.tag if hv.type_tag else None);
                fields.append(f"{fname}: {ftype}");
                put(f"{name}.{fname}", "has", hv, ftype);
            }
            for ab in el.get_methods() {
                if ab.name_ref is None {
                    continue;
                }
                member_spans.append((ab.loc.first_line, ab.loc.last_line));
                put(
                    f"{name}.{ab.name_ref.sym_name}", "method", ab, node_text(ab.signature)
                );
            }
            own_lines: list[str] = [];
            for i in range(el.loc.first_line, el.loc.last_line + 1) {
                if any([a <= i <= b for (a, b) in member_spans]) {
                    continue;
                }
                if 0 < i <= len(lines) {
                    own_lines.append(lines[i - 1].rstrip());
                }
            }
            bases = ", ".join([node_text(b) for b in (el.base_classes or [])]);
            taken.add(name);
            rows.append(
                EditSymbol(
                    key=name,
                    kind=kind,
                    line=el.loc.first_line,
                    end_line=el.loc.last_line,
                    text="\n".join(own_lines),
                    signature=f"{kind}({bases}) " + "; ".join(fields)
                )
            );
        } elif isinstance(el, uni.Enum) {
            put(
                el.name.sym_name,
                "enum",
                el,
                lines_text(lines, el.loc.first_line, el.loc.last_line)
            );
        } elif isinstance(el, uni.Ability) {
            if el.name_ref is None {
                continue;
            }
            put(el.name_ref.sym_name, "def", el, node_text(el.signature));
        } elif isinstance(el, uni.GlobalVars) {
            for asg in el.assignments {
                tgt = ", ".join([node_text(t) for t in asg.target]);
                if not tgt {
                    continue;
                }
                put(
                    tgt.split(":")[0].strip(),
                    "glob",
                    asg,
                    node_text(asg.type_tag) if asg.type_tag else tgt
                );
            }
        } elif isinstance(el, uni.Test) {
            put(f"test {node_text(el.name)}", "test", el, "");
        }
    }
    for idef in module.get_all_sub_nodes(uni.ImplDef) {
        parts = [t.sym_name for t in idef.target];
        if parts {
            put("impl " + ".".join(parts), "impl", idef, "");
        }
    }
    return rows;
}

impl import_text_rows(text: str, path: str) -> list[str] {
    out: list[str] = [];
    if not text.strip() {
        return out;
    }
    (module, had_error) = parse_woven(text, path, None, [], load_kernel=False);
    lines = text.splitlines();
    for imp in module.get_all_sub_nodes(uni.Import) {
        t = " ".join(lines_text(lines, imp.loc.first_line, imp.loc.last_line).split());
        if t and t not in out {
            out.append(t);
        }
    }
    return out;
}

impl wiring_fact_texts(recs: list[WireRec]) -> dict[tuple[str, ...], str] {
    found: dict[tuple[str, ...], str] = {};
    for (consumer, binding) in wiring_facts(recs) {
        arrow = "++>" if binding.injected else "-->";
        head = " ".join(
            [
                w
                for w in binding.form.split(" ")
                if w in ("comptime", "include", "type")
            ]
                + [binding.provider]
        );
        if binding.is_module_form() {
            alias = f" as {binding.alias}" if binding.alias else "";
            text = f"{head}{alias} {arrow} {consumer}";
        } else {
            item = binding.name + (f" as {binding.alias}" if binding.alias else "");
            text = f"{head} {arrow} {consumer} {{ {item} }}";
        }
        found[(consumer, ) + binding.key()] = text;
    }
    return found;
}

impl wiring_change_rows(
    old_text: str, new_text: str, path: str
) -> list[WiringChange] {
    out: list[WiringChange] = [];
    old_rec = parse_records(old_text, path) if old_text.strip() else (False, [], []);
    new_rec = parse_records(new_text, path);
    if new_rec[0] {
        out.append(
            WiringChange(
                kind="archwire syntax error",
                detail="the new archwire.jac does not parse; its wiring is incomplete"
            )
        );
    }
    old_facts = wiring_fact_texts(old_rec[1]);
    new_facts = wiring_fact_texts(new_rec[1]);
    for (k, text) in new_facts.items() {
        if k not in old_facts {
            out.append(WiringChange(kind="new wire", detail=text, module=k[0]));
        }
    }
    for (k, text) in old_facts.items() {
        if k not in new_facts {
            out.append(WiringChange(kind="removed wire", detail=text, module=k[0]));
        }
    }
    old_rules = {r.name: rule_text(r) for r in old_rec[2]};
    new_rules = {r.name: rule_text(r) for r in new_rec[2]};
    for (name, text) in new_rules.items() {
        if name not in old_rules {
            out.append(WiringChange(kind="new rule", detail=text));
        } elif old_rules[name] != text {
            out.append(
                WiringChange(
                    kind="changed rule", detail=f"{old_rules[name]}  =>  {text}"
                )
            );
        }
    }
    for (name, text) in old_rules.items() {
        if name not in new_rules {
            out.append(WiringChange(kind="removed rule", detail=text));
        }
    }
    return out;
}

impl wired_dependent_files(head: str, names: list[str]) -> WiredFiles {
    real = os.path.realpath(head);
    spec = wiring_for_path(real);
    if spec is None or not spec.owns(real) {
        return WiredFiles(owned=False);
    }
    wanted = set(names);
    out = WiredFiles(owned=True);
    for w in spec.wires {
        split = spec.split_consumer(w.provider);
        if split is None {
            continue;
        }
        pfile = spec.module_file(split[0]);
        if pfile is None or os.path.realpath(pfile) != real {
            continue;
        }
        carried = set([it[0] for it in w.items]);
        if split[1] {
            carried.add(split[1][0]);
        }
        if carried and not (carried & wanted) {
            continue;
        }
        for consumer in w.consumers {
            csplit = spec.split_consumer(consumer);
            if csplit is None {
                continue;
            }
            cfile = spec.module_file(csplit[0]);
            if cfile is None {
                continue;
            }
            creal = os.path.realpath(cfile);
            if creal != real and creal not in out.files {
                out.files.append(creal);
            }
        }
    }
    return out;
}

impl wiring_files_of(arch_path: str, consumers: list[str]) -> list[str] {
    spec = wiring_for_path(arch_path);
    files: list[str] = [];
    if spec is None {
        return files;
    }
    for consumer in consumers {
        csplit = spec.split_consumer(consumer) if consumer else None;
        if csplit is None {
            continue;
        }
        cfile = spec.module_file(csplit[0]);
        if cfile is not None {
            creal = os.path.realpath(cfile);
            if creal not in files {
                files.append(creal);
            }
        }
    }
    return files;
}

impl wire_violation(
    spec: WiringSpec, provider: str, consumer: str, names: list[str], whole: bool
) -> str {
    governing = spec.rules_governing(provider, consumer, True);
    if not governing {
        if spec.needs_rule(provider, consumer, True) {
            return f"E2099 crosses from package {spec.top_package(provider)} into {spec.top_package(
                consumer
            )} and no rule admits it";
        }
        return "";
    }
    admitting = spec.rules_admitting(provider, consumer, True);
    if not admitting {
        return "E2090 not permitted by " + ", ".join([r.name for r in governing]);
    }
    allowed = WiringSpec.admitted_names(admitting);
    if allowed is None {
        return "";
    }
    if whole or not names {
        return "E2091 a whole-module wire cannot pass a payload rule";
    }
    bad = [
        n
        for n in names
        if n not in allowed
    ];
    if bad {
        return "E2091 not admitted: " + ", ".join(bad);
    }
    return "";
}

impl wire_form(w: WireRec) -> str {
    if w.is_absorb {
        return "include";
    }
    form = "import" if w.is_module_form else "import from";
    if w.is_comptime {
        form = "comptime " + form;
    }
    if w.is_typed {
        form = "type " + form;
    }
    return form;
}

impl wiring_model_of(arch_path: str) -> WiringModel {
    real = os.path.realpath(arch_path);
    spec = wiring_for_path(real);
    if spec is None {
        raise KernelError(f"{real} governs no wiring: it is not an archwire.jac in reach");
    }
    model = WiringModel(arch_path=real, parsed=not spec.parse_failed);
    known: dict[str, WiringModule] = {};
    def note(local: str, project: bool) {
        held = known.get(local);
        if held is not None {
            held.project = held.project or project;
            return;
        }
        path = spec.module_file(local);
        row = WiringModule(
            local=local,
            file=os.path.realpath(path) if path else "",
            import_name=spec.import_name(local) if path else "",
            project=project
        );
        known[local] = row;
        model.modules.append(row);
    }
    for local in spec.project_modules() {
        note(local, True);
    }
    for w in spec.wires {
        note(w.provider, False);
        names = [(n if not a else f"{n} as {a}") for (n, a) in w.items];
        for consumer in w.consumers {
            split = spec.split_consumer(consumer);
            (cmod, scope) = (consumer, []);
            if split is not None {
                (cmod, scope) = split;
            }
            note(cmod, False);
            link = WiringEdge(
                provider=w.provider,
                consumer=cmod,
                scope=list(scope),
                names=names,
                form=wire_form(w),
                injected=w.is_injected,
                line=w.line,
                crosses=spec.top_package(w.provider) != spec.top_package(cmod),
                rules=[r.name for r in spec.rules_admitting(w.provider, cmod, True)],
                violation=wire_violation(
                    spec, w.provider, cmod, [n for (n, a) in w.items], w.is_module_form
                )
            );
            if link.violation.startswith(("E2090", "E2091")) {
                link.rules = [];
            }
            for r in spec.rules {
                for sp in r.sources {
                    for tp in r.targets {
                        if sp.matches(w.provider) and tp.matches(cmod) {
                            link.arms.append(f"{r.name}\x1f{sp.text}\x1f{tp.text}");
                        }
                    }
                }
            }
            model.edges.append(link);
        }
    }
    for r in spec.rules {
        model.rules.append(
            WiringRule(
                name=r.name,
                sources=[p.text for p in r.sources],
                targets=[p.text for p in r.targets],
                names=sorted(r.item_names) if r.item_names else [],
                governs=[
                    row.local
                    for row in model.modules
                    if any([p.matches(row.local) for p in r.sources])
                ]
            )
        );
    }
    return model;
}

impl token_symbol_rows(module: uni.Module, path: str) -> list[TokenSymbol] {
    rows: list[TokenSymbol] = [];
    for nd in symbol_nodes(module, path) {
        row = TokenSymbol(
            line=nd.loc.first_line,
            col=nd.loc.col_start - 1,
            end_col=nd.loc.col_end - 1,
            name=str(nd.value)
        );
        if nd.sym is not None {
            d = definition_symbol(nd.sym);
            row.name = d.sym_name;
            row.kind = d.sym_type.value;
            row.dotted = d.sym_dotted_name;
            decl = d.decl;
            if decl is not None {
                row.decl_path = str(decl.loc.mod_path or "");
                row.decl_line = decl.loc.first_line;
                row.decl_col = max(0, decl.loc.col_start - 1);
            }
        }
        rows.append(row);
    }
    return rows;
}

impl assignment_hint_rows(module: uni.Module, path: str) -> list[InlayHint] {
    rows: list[InlayHint] = [];
    seen: set[int] = set();
    for asg in module.get_all_sub_nodes(uni.Assignment) {
        if asg.type_tag is not None
            or len(asg.target) != 1
            or not isinstance(asg.target[0], uni.Name) {
            continue;
        }
        tgt = asg.target[0];
        if not belongs_to(tgt, path) {
            continue;
        }
        sym = tgt.sym;
        if sym is None or id(sym) in seen {
            continue;
        }
        seen.add(id(sym));
        txt = str(tgt.type) if tgt.type is not None else "";
        if not txt or "Unknown" in txt or len(txt) > 48 {
            continue;
        }
        rows.append(
            InlayHint(
                line=tgt.loc.first_line,
                col=tgt.loc.col_end,
                label=f": {txt}",
                kind="type"
            )
        );
    }
    return rows;
}

impl token_stream(text: str, path: str) -> TokenStream {
    (tokens, comments, _diags, _errs) = tokenize_full(text, path);
    out = TokenStream();
    for tok in tokens {
        loc = tok.loc;
        out.tokens.append(
            SourceToken(
                kind=tok.kind.name,
                value=str(tok.value),
                line=loc.line,
                col=loc.col_start,
                end_line=loc.end_line,
                end_col=loc.col_end
            )
        );
    }
    for c in comments {
        out.comments.append(
            SourceSpan(
                path=path,
                line=c.line,
                col=c.col_start,
                end_line=c.end_line,
                end_col=c.col_end
            )
        );
    }
    return out;
}
