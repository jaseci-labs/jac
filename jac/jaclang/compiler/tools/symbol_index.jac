import os;
import json;
import zlib;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.tools.unparse_pass { unparse_node }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.progstate { DepGraph }
import from jaclang.compiler.driver.compilation_context {
    InputManifest,
    SourceStore,
    cache_scope
}
import from jaclang.compiler.driver.jir {
    SEC_SYMINDEX,
    HEADER_SIZE,
    parse_header,
    read_section_bytes,
    get_module_cache_path,
    write_module_cache,
    jir_env_matches
}

glob _ARCH_KIND: dict[str, str] = {
         "node": "node",
         "walker": "walker",
         "edge": "edge",
         "obj": "obj",
         "class": "class",
         "enum": "enum"
     };

obj SourceRef {
    has file: str,
        line: int,
        col: int = 0,
        role: str = "use",
        snippet: str = "",
        end_line: int = 0,
        end_col: int = 0;

    static def from_node(nd: uni.NameAtom, role: str) -> SourceRef {
        loc = nd.loc;
        return SourceRef(
            os.path.realpath(loc.mod_path),
            loc.first_line,
            loc.col_start,
            role,
            end_line=loc.last_line,
            end_col=loc.col_end
        );
    }

    static def from_dict(data: dict) -> SourceRef {
        return SourceRef(
            str(data['file']),
            int(data['line']),
            int(data['col']),
            str(data['role']),
            str(data.get('snippet', '')),
            int(data.get('end_line', 0)),
            int(data.get('end_col', 0))
        );
    }

    def render -> str {
        loc = f"{self.file}:{self.line}";
        return f"{loc}  {self.snippet}" if self.snippet else loc;
    }

    def to_dict -> dict {
        return {
            "file": self.file,
            "line": self.line,
            "col": self.col,
            "role": self.role,
            "snippet": self.snippet,
            "end_line": self.end_line,
            "end_col": self.end_col
        };
    }
}

obj SymbolInfo {
    has name: str,
        kind: str,
        file: str,
        line: int,
        col: int = 0,
        type_str: str = "",
        doc: str = "",
        signature: str = "",
        fields: list[str] = [],
        abilities: list[str] = [],
        base_classes: list[str] = [],
        is_genai: bool = False,
        workspace_visible: bool = True;

    def render -> str {
        head = f"{self.kind} {self.name}";
        if self.signature {
            head += self.signature;
        } elif self.type_str {
            head += f": {self.type_str}";
        }
        lines = [f"{head}    [{self.file}:{self.line}]"];
        if self.base_classes {
            lines.append("  extends: " + ", ".join(self.base_classes));
        }
        for f in self.fields {
            lines.append(f"  has {f}");
        }
        for a in self.abilities {
            lines.append(f"  def {a}");
        }
        if self.doc {
            lines.append("  " + self.doc.strip().splitlines()[0]);
        }
        return "\n".join(lines);
    }

    def to_dict -> dict {
        return {
            "name": self.name,
            "kind": self.kind,
            "file": self.file,
            "line": self.line,
            "col": self.col,
            "type_str": self.type_str,
            "doc": self.doc,
            "signature": self.signature,
            "fields": self.fields,
            "abilities": self.abilities,
            "base_classes": self.base_classes,
            "is_genai": self.is_genai,
            "workspace_visible": self.workspace_visible
        };
    }

    static def from_dict(d: dict) -> SymbolInfo {
        return SymbolInfo(
            name=str(d.get("name", "")),
            kind=str(d.get("kind", "symbol")),
            file=str(d.get("file", "")),
            line=int(d.get("line", 0)),
            col=int(d.get("col", 0)),
            type_str=str(d.get("type_str", "")),
            doc=str(d.get("doc", "")),
            signature=str(d.get("signature", "")),
            fields=list(d.get("fields", [])),
            abilities=list(d.get("abilities", [])),
            base_classes=list(d.get("base_classes", [])),
            is_genai=bool(d.get("is_genai", False)),
            workspace_visible=bool(d.get("workspace_visible", True))
        );
    }
}


obj SymbolExtractor {
    def _collect_syms(scope: uni.UniScopeNode, out: list[uni.Symbol]) {
        for sym in scope.names_in_scope.values() {
            out.append(sym);
        }
        for bucket in scope.names_in_scope_overload.values() {
            for sym in bucket {
                out.append(sym);
            }
        }
        for kid in scope.kid_scope {
            self._collect_syms(kid, out);
        }
    }

    def _kind_of(owner: uni.UniNode) -> str {
        if isinstance(owner, uni.Archetype) {
            raw = "";
            try {
                raw = str(owner.arch_type.value);
            } except Exception as e {
                _ = e;
            }
            return _ARCH_KIND.get(raw, raw or "obj");
        }
        if isinstance(owner, uni.Enum) {
            return "enum";
        }
        if isinstance(owner, uni.Ability) {
            return "ability";
        }
        if isinstance(owner, uni.HasVar) {
            return "field";
        }
        if isinstance(owner, uni.Module) {
            return "module";
        }
        return "symbol";
    }

    def _expr_str(expr: uni.UniNode | None) -> str {
        if expr is None {
            return "";
        }
        try {
            return str(unparse_node(expr)).strip();
        } except Exception as e {
            _ = e;
            return "";
        }
    }

    def _doc_of(owner: uni.UniNode) -> str {
        try {
            if isinstance(owner, uni.AstDocNode) {
                doc = owner.doc;
                if doc is not None and doc.value {
                    return str(doc.value).strip().strip('"');
                }
            }
        } except Exception as e {
            _ = e;
        }
        return "";
    }

    def _info(sym: uni.Symbol) -> SymbolInfo | None {
        decl = sym.decl;
        if decl is None {
            return None;
        }
        owner: uni.UniNode = decl;
        try {
            owner = decl.name_of;
        } except Exception as e {
            _ = e;
        }
        loc = decl.loc;
        info = SymbolInfo(
            name=sym.sym_name,
            kind=self._kind_of(owner),
            file=loc.mod_path if loc else "",
            line=loc.first_line if loc else 0,
            col=loc.col_start if loc else 0,
            doc=self._doc_of(owner),
            workspace_visible=isinstance(
                sym.parent_tab, (uni.Module, uni.Archetype, uni.Enum)
            )
        );
        if isinstance(owner, uni.Archetype) {
            self._fill_archetype(info, owner);
        } elif isinstance(owner, uni.Ability) {
            info.signature = self._expr_str(owner.signature);
            info.is_genai = bool(getattr(owner, "is_genai_ability", False));
        } elif isinstance(owner, uni.HasVar) {
            info.type_str = self._expr_str(owner.type_tag.tag)
                if owner.type_tag
                else "";
        } else {
            try {
                owner_type = owner?.type;
                info.type_str = str(owner_type) if owner_type else "";
            } except Exception as e {
                _ = e;
            }
        }
        return info;
    }

    def _fill_archetype(info: SymbolInfo, arch: uni.Archetype) {
        try {
            for v in arch.get_has_vars() {
                vt = self._expr_str(v.type_tag.tag) if v.type_tag else "";
                info.fields.append(
                    f"{v.name.sym_name}: {vt}" if vt else v.name.sym_name
                );
            }
        } except Exception as e {
            _ = e;
        }
        try {
            for m in arch.get_methods() {
                mname = m.name_ref.sym_name if m.name_ref else "?";
                tag = " by llm" if getattr(m, "is_genai_ability", False) else "";
                info.abilities.append(mname + "()" + tag);
            }
        } except Exception as e {
            _ = e;
        }
        try {
            if arch.base_classes {
                for b in arch.base_classes {
                    info.base_classes.append(self._expr_str(b));
                }
            }
        } except Exception as e {
            _ = e;
        }
    }
}

def definition_symbol(sym: uni.Symbol, preserve_alias: bool = False) -> uni.Symbol {
    current = sym;
    seen: set[int] = set();
    while current.provider is not None and id(current) not in seen {
        if preserve_alias
            and isinstance(current.decl.parent, uni.ModuleItem)
            and current.decl.parent.alias is not None {
            break;
        }
        seen.add(id(current));
        target = current.provider.definition();
        if target is None or target is current {
            break;
        }
        current = target;
    }
    return current;
}

def symbol_key(sym: uni.Symbol) -> str {
    resolved = definition_symbol(sym, preserve_alias=True);
    loc = resolved.decl.loc;

    return json.dumps(
        [
            os.path.realpath(loc.mod_path),
            loc.first_line,
            loc.col_start,
            resolved.sym_dotted_name
        ],
        separators=(',', ':')
    );
}

obj IndexShard {
    has path: str,
        context: str,
        inputs: InputManifest,
        definitions: dict[str, SymbolInfo],
        references: dict[str, list[SourceRef]],
        dependencies: dict[str, list[str]] = {},
        interface: str | None = None,
        body_dependencies: set[str] = set();

    def to_bytes -> bytes {
        return zlib.compress(
            json.dumps(
                {
                    'version': 3,
                    'path': self.path,
                    'context': self.context,
                    'inputs': self.inputs.to_dict(),
                    'dependencies': self.dependencies,
                    'interface': self.interface,
                    'body_dependencies': sorted(self.body_dependencies),
                    'definitions': {
                        key: info.to_dict() for (key, info) in self.definitions.items()
                    },
                    'references': {
                        key: [ref.to_dict() for ref in refs]
                        for (key, refs) in self.references.items()
                    }
                },
                separators=(',', ':')
            ).encode(
                'utf-8'
            )
        );
    }

    static def from_bytes(data: bytes) -> IndexShard {
        value = json.loads(zlib.decompress(data));
        if value['version'] != 3 {
            raise ValueError('Unsupported symbol index format');
        }
        return IndexShard(
            str(value['path']),
            str(value['context']),
            InputManifest.from_dict(value['inputs']),
            {
                str(key): SymbolInfo.from_dict(info)
                for (key, info) in value['definitions'].items()
            },
            {
                str(key): [SourceRef.from_dict(ref) for ref in refs]
                for (key, refs) in value['references'].items()
            },
            {
                str(path): [str(target) for target in targets]
                for (path, targets) in value['dependencies'].items()
            },
            str(value['interface']) if value['interface'] is not None else None,
            {str(path) for path in value['body_dependencies']}
        );
    }
}

obj SymbolIndex(SymbolExtractor) {
    has shards: dict[tuple[str, str], IndexShard] = {},
        symbols: dict[str, set[tuple[str, str]]] = {},
        names: dict[str, set[tuple[str, str]]] = {};

    def refresh_dependents(previous: IndexShard, current: IndexShard) {
        if previous.interface is None or previous.interface != current.interface {
            return;
        }
        paths = {previous.path, *previous.inputs.annexes.get(previous.path, [])};
        if previous.inputs.annexes.get(previous.path, [])
            != current.inputs.annexes.get(current.path, []) {
            return;
        }
        changed = {
            path for path in paths
            if previous.inputs.files.get(path) != current.inputs.files.get(path)
        };
        if not changed {
            return;
        }
        for shard in self.shards.values() {
            if shard.context != current.context
                or shard.path in paths
                or shard.body_dependencies & paths {
                continue;
            }
            relevant = changed & shard.inputs.files.keys();
            if not relevant or any(
                shard.inputs.files[path] != previous.inputs.files.get(path)
                for path in relevant
            ) {
                continue;
            }
            files = dict(shard.inputs.files);
            for path in relevant {
                files[path] = current.inputs.files.get(path);
            }
            shard.inputs = InputManifest(files, dict(shard.inputs.annexes));
        }
    }

    def discard(path: str, context: str) {
        key = (context, os.path.realpath(path));
        previous = self.shards.pop(key, None);
        if previous is None {
            return;
        }
        for symbol in previous.references {
            self.symbols[symbol].discard(key);
            if not self.symbols[symbol] {
                self.symbols.pop(symbol);
            }
        }
        for info in previous.definitions.values() {
            entries = self.names.get(info.name);
            if entries is not None {
                entries.discard(key);
                if not entries {
                    self.names.pop(info.name);
                }
            }
        }
    }

    def install(shard: IndexShard) {
        self.discard(shard.path, shard.context);
        key = (shard.context, shard.path);
        self.shards[key] = shard;
        for symbol in shard.references {
            self.symbols.setdefault(symbol, set()).add(key);
        }
        for info in shard.definitions.values() {
            self.names.setdefault(info.name, set()).add(key);
        }
    }

    def collect(
        module: uni.Module,
        context: str,
        inputs: InputManifest,
        deps: DepGraph | None = None
    ) -> IndexShard {
        paths = {os.path.realpath(module.loc.mod_path)};
        paths.update(inputs.annexes.get(os.path.realpath(module.loc.mod_path), []));
        definitions: dict[str, SymbolInfo] = {};
        references: dict[str, list[SourceRef]] = {};
        seen: set[tuple[str, int, int, str]] = set();
        for nd in module._in_mod_nodes {
            if not isinstance(nd, uni.NameAtom) {
                continue;
            }
            sym = nd.sym;
            if sym is None
                or not sym.defn
                or os.path.realpath(nd.loc.mod_path) not in paths {
                continue;
            }
            key = symbol_key(sym);
            resolved = definition_symbol(sym, preserve_alias=True);
            role = 'def' if any(nd is decl for decl in resolved.defn) else 'use';
            ref = SourceRef.from_node(nd, role);
            coordinate = (ref.file, ref.line, ref.col, key);
            if coordinate in seen {
                continue;
            }
            seen.add(coordinate);
            references.setdefault(key, []).append(ref);
            if role == 'def' and key not in definitions {
                info = self._info(resolved);
                if info is not None {
                    definitions[key] = info;
                }
            }
        }
        return IndexShard(
            os.path.realpath(module.loc.mod_path),
            context,
            inputs,
            definitions,
            references,
            {
                path: sorted(targets)
                for (path, targets) in deps.dependencies.items()
                if path in inputs.files
            }
                if deps is not None
                else {}
        );
    }

    def persist(shard: IndexShard, options: CompileOptions | None = None) -> bool {
        if not shard.inputs.is_current() {
            return False;
        }
        with cache_scope(shard.context, options) {
            return write_module_cache(
                shard.path, None, {SEC_SYMINDEX: shard.to_bytes()}
            );
        }
    }

    def load(
        path: str,
        context: str,
        store: SourceStore,
        options: CompileOptions | None = None
    ) -> bool {
        path = os.path.realpath(path);
        try {
            with cache_scope(context, options) {
                data = get_module_cache_path(path).read_bytes();
                header = parse_header(data[:HEADER_SIZE]);
                if header is None
                    or not header.is_compatible()
                    or not jir_env_matches(data, path) {
                    return False;
                }
                section = read_section_bytes(data, SEC_SYMINDEX);
                if section is None {
                    return False;
                }
                shard = IndexShard.from_bytes(section);
                if shard.path != path
                    or shard.context != context
                    or not shard.inputs.is_current(store) {
                    return False;
                }
                self.install(shard);
                return True;
            }
        } except (
            OSError,
            ValueError,
            KeyError,
            TypeError,
            AttributeError,
            zlib.error
        ) {
            return False;
        }
    }

    def references_for(key: str, store: SourceStore) -> list[SourceRef] {
        found: dict[tuple[str, int, int], SourceRef] = {};
        for shard_key in list(self.symbols.get(key, set())) {
            shard = self.shards[shard_key];
            if not shard.inputs.is_current(store) {
                self.discard(shard.path, shard.context);
                continue;
            }
            for ref in shard.references[key] {
                found[(ref.file, ref.line, ref.col)] = ref;
            }
        }
        return [found[coordinate] for coordinate in sorted(found)];
    }

    def references_for_symbol(
        sym: uni.Symbol, store: SourceStore, include_declaration: bool = True
    ) -> list[SourceRef] {
        refs = self.references_for(symbol_key(sym), store);
        if include_declaration {
            for decl in definition_symbol(sym, preserve_alias=True).defn {
                store.record_module(decl.loc.mod_path);
                refs.append(SourceRef.from_node(decl, 'def'));
            }
        }
        found = {
            (ref.file, ref.line, ref.col): ref
            for ref in refs
            if include_declaration or ref.role != 'def'
        };
        return [found[coordinate] for coordinate in sorted(found)];
    }

    def lookup(name: str, store: SourceStore) -> list[SymbolInfo] {
        found: dict[str, SymbolInfo] = {};
        for shard_key in list(self.names.get(name, set())) {
            shard = self.shards[shard_key];
            if not shard.inputs.is_current(store) {
                self.discard(shard.path, shard.context);
                continue;
            }
            for (key, info) in shard.definitions.items() {
                if info.name == name {
                    found[key] = info;
                }
            }
        }
        return [found[key] for key in sorted(found)];
    }

    def search(query: str, store: SourceStore, limit: int = 256) -> list[SymbolInfo] {
        found: list[SymbolInfo] = [];
        query = query.casefold();
        for name in sorted(self.names) {
            if query in name.casefold() {
                found.extend(
                    info
                    for info in self.lookup(name, store)
                    if info.workspace_visible
                );
                if len(found) >= limit {
                    break;
                }
            }
        }
        return found[:limit];
    }
}
