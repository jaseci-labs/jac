"""Compiler-backed code intelligence for tools and agents.

A headless, protocol-agnostic facade over the Jac compiler's symbol tables and
type information. Where a text search answers "which lines contain this
string", `CodeIntelligence` answers "where is this symbol defined, everywhere
it is used, what type it has, and which walkers traverse it" -- the questions
that require the compiler, not a regex.

It exists so tools and coding agents can navigate the *graph of meaning*
instead of treating a project as text. The Jac language server consumes the
same symbol data through its own LSP-shaped surface; this facade returns plain
Jac objects (`SymbolInfo`, `SourceRef`, ...) so a caller never touches a raw
AST node or an LSP wire type.

The model is rebuild-on-write: `load` compiles the project once, `refresh`
rebuilds after an edit. Unlike the language server it does not track
keystroke-level edits -- an agent writes whole files, so a per-write rebuild
is enough.
"""

import os;
import time;
import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.passes { Alert }

# Directories never worth compiling -- generated output, vendored deps, VCS.
glob _SKIP_DIRS: set[str] = {"__pycache__","__jac_gen__",".git",".venv","venv","node_modules","build","dist",".mypy_cache",".pytest_cache"},
     # Archetype keyword -> readable kind. Falls back to the raw token value.
     _ARCH_KIND: dict[str, str] = {
         "node": "node",
         "walker": "walker",
         "edge": "edge",
         "obj": "obj",
         "class": "class",
         "enum": "enum"
     };


"""Resolve a path to its canonical absolute form."""
def _real(path: str) -> str {
    try {
        return str(Path(path).resolve());
    } except Exception {
        return path;
    }
}


"""A single source location -- a symbol's definition or one of its uses."""
obj SourceRef {
    has file: str,
        line: int,
        col: int = 0,
        role: str = "use",
        snippet: str = "";

    def render -> str {
        loc = f"{self.file}:{self.line}";
        return f"{loc}  {self.snippet}" if self.snippet else loc;
    }

    """A JSON-friendly mapping of this reference, for machine consumers."""
    def to_dict -> dict {
        return {
            "file": self.file,
            "line": self.line,
            "col": self.col,
            "role": self.role,
            "snippet": self.snippet
        };
    }
}


"""A resolved symbol: where it is defined, its kind, type, and structure.

`kind` is one of node/walker/edge/obj/class/enum/ability/field/global/symbol.
The structural fields (`fields`, `abilities`, `base_classes`) are populated
only for archetypes; they are empty for everything else.
"""
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
        is_genai: bool = False;

    """Render a compact, human/LLM-readable description of the symbol."""
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

    """A JSON-friendly mapping of this symbol, for machine consumers."""
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
            "is_genai": self.is_genai
        };
    }
}


"""A compiler diagnostic -- an error or warning at a source location."""
obj Diagnostic {
    has file: str,
        line: int,
        severity: str,
        message: str;

    def render -> str {
        return f"{self.severity}: {self.file}:{self.line}: {self.message}";
    }

    """A JSON-friendly mapping of this diagnostic, for machine consumers."""
    def to_dict -> dict {
        return {
            "file": self.file,
            "line": self.line,
            "severity": self.severity,
            "message": self.message
        };
    }
}


"""A stable identity key for a diagnostic -- file, line, severity, message.

Used to diff diagnostics across a recompile: a key absent before an edit and
present after it identifies a problem the edit introduced.
"""
def _diag_key(d: Diagnostic) -> str {
    return f"{_real(d.file)}:{d.line}:{d.severity}:{d.message}";
}


"""A walker entry point: an ability that runs when a walker visits a node."""
obj EntryPoint {
    has walker_name: str,
        ability: str,
        node_type: str,
        event: str,
        file: str = "",
        line: int = 0;

    def render -> str {
        return f"{self.walker_name}.{self.ability}  ({self.event} {self.node_type})  [{self.file}:{self.line}]";
    }

    """A JSON-friendly mapping of this entry point, for machine consumers."""
    def to_dict -> dict {
        return {
            "walker_name": self.walker_name,
            "ability": self.ability,
            "node_type": self.node_type,
            "event": self.event,
            "file": self.file,
            "line": self.line
        };
    }
}


"""A typed neighbourhood of code, packed for prompt assembly.

`slice_for` builds one: the target symbol, the symbols of the types it
depends on (declared field types, base classes), and every place it is used.
`render` turns it into a compact text block a model can read instead of
whole files.
"""
obj ContextSlice {
    has query: str,
        target: SymbolInfo | None = None,
        related: list[SymbolInfo] = [],
        uses: list[SourceRef] = [];

    def render -> str {
        if self.target is None {
            return f"(no symbol named {self.query} was found)";
        }
        parts = ["# Definition", self.target.render()];
        if self.related {
            parts.append("\n# Referenced types");
            for s in self.related {
                parts.append(s.render());
            }
        }
        if self.uses {
            parts.append(f"\n# Used in {len(self.uses)} place(s)");
            for u in self.uses {
                parts.append("  " + u.render());
            }
        }
        return "\n".join(parts);
    }

    """A JSON-friendly mapping of this slice, for machine consumers.

    Nested records are serialised through their own `to_dict`, so the slice
    shape stays in lockstep with the `SymbolInfo`/`SourceRef` contracts.
    """
    def to_dict -> dict {
        return {
            "query": self.query,
            "target": self.target.to_dict() if self.target is not None else None,
            "related": [s.to_dict() for s in self.related],
            "uses": [u.to_dict() for u in self.uses]
        };
    }
}


"""Compiler-backed semantic queries over a Jac project.

Construct with the project root, call `load` once, then query. After an edit,
call `refresh` to rebuild. All query methods return plain `SymbolInfo` /
`SourceRef` / `Diagnostic` objects -- never raw AST nodes.
"""
obj CodeIntelligence {
    has proj_dir: str,
        type_check: bool = True,
        # Parse-only mode: compile each file with `parse_str` rather than the
        # full pipeline, skipping symbol/import resolution and type inference.
        # Valid only for the structural queries (`archetypes`, `entry_points`)
        # that read declarations straight off the AST -- name- and type-
        # addressed queries need the symbol tables a parse alone never builds.
        structural: bool = False,
        # Optional observer invoked after every compile (`load`/`refresh`) with
        # a stats dict {op, file, recompiled, total, ms}. Lets a caller (the
        # `jac ai` live view) surface when code intelligence recompiles and how
        # much it touched, without this facade knowing anything about rendering.
        on_event: any = None;

    def postinit {
        self._root_real: str = _real(self.proj_dir);
        self.prog: JacProgram = JacProgram();
        # The program tracks the reverse-dependency graph for us: every compile
        # records its import edges structurally, so `transitive_dependents` is
        # complete (survives cache hits) and there is no parallel map to keep.
        self.prog._track_dependencies = True;
        self._files: list[str] = [];
        self._file_set: set[str] = set();
        self._compiled: dict[str, uni.Module] = {};
        # Signature of the project's directory mtimes -- used by `refresh` to
        # detect a file being added or removed out of band.
        self._dir_sig: dict[str, float] = {};
        self._loaded: bool = False;
    }

    #-- lifecycle --------------------------------------------------------
    """Discover and compile every non-annex .jac file under the project root.

    Annex files (`.impl.jac`, `.test.jac`) are skipped: the compiler splices
    them into their parent module automatically. A file that fails to compile
    is skipped, not fatal -- partial knowledge still beats none.
    """
    def load {
        t0 = time.time();
        self._files = self._discover();
        self._file_set = {_real(f) for f in self._files};
        self.prog.errors_had = [];
        self.prog.warnings_had = [];
        self._compiled = {};
        for f in self._files {
            self._compile_one(f);
        }
        self._dir_sig = self._dir_signature();
        self._loaded = True;
        self._emit("load", "", len(self._files), t0);
    }

    """Notify the `on_event` observer that a compile just happened (if set)."""
    def _emit(op: str, file: str, recompiled: int, t0: float) {
        cb = self.on_event;
        if cb is None {
            return;
        }
        try {
            cb(
                {
                    "op": op,
                    "file": file,
                    "recompiled": recompiled,
                    "total": len(self._file_set),
                    "ms": (time.time() - t0) * 1000.0
                }
            );
        } except Exception as e {
            _ = e;
        }
    }

    """Rebuild after a file was created, edited, or deleted -- always incremental.

    Given a `file`, only that module and the modules that import it
    (transitively) are recompiled; the rest are served from the compiler's
    cache, so the cost is an LSP-save, not a project rebuild. Creating a file
    is handled the same way -- it is registered in place rather than triggering
    a full rediscovery -- so scaffolding an app file-by-file stays linear. With
    no `file`, or before the first `load`, this is a full build. The transitive
    importer set comes from the program's own reverse-dependency graph
    (`transitive_dependents`), kept complete by `record_module_dependencies`.
    """
    def refresh(file: str = "") -> None {
        if not file or not self._loaded {
            # A full build; `load` emits its own event.
            self.load();
            return;
        }
        t0 = time.time();
        target = self._head_for(_real(file));
        mode = "edit";
        if not Path(target).exists() {
            # Deletion: drop the module, then recompile whatever imported it so
            # the now-broken references surface. The file itself is not recompiled.
            mode = "delete";
            self._drop_file(target);
            stale: set[str] = self.prog.transitive_dependents(target);
        } else {
            if target not in self._file_set {
                # A file the agent just created. Register it in place instead of
                # rediscovering the project, and resync the directory signature.
                mode = "create";
                self._files.append(target);
                self._file_set.add(target);
                self._dir_sig = self._dir_signature();
            }
            # The changed file plus every module that imports it (transitively).
            stale = self.prog.transitive_dependents(target);
            stale.add(target);
        }
        for p in stale {
            try {
                self.prog.invalidate_module(p);
            } except Exception as e {
                _ = e;
            }
        }
        # Drop the recompile set's old diagnostics; the recompile re-reports
        # current ones. Untouched files' diagnostics are left intact.
        self.prog.errors_had = self._keep_diagnostics(self.prog.errors_had, stale);
        self.prog.warnings_had = self._keep_diagnostics(self.prog.warnings_had, stale);
        recompiled = 0;
        for p in stale {
            if p in self._file_set {
                self._compile_one(p);
                recompiled += 1;
            }
        }
        self._emit(mode, target, recompiled, t0);
    }

    """Resolve an annex (`.impl.jac`/`.test.jac`) path to its owning head module.

    Annex files are spliced into their parent module by the compiler and are
    never compiled standalone, so a write to one must recompile the head. A
    sibling annex (`foo.impl.jac`) maps to `foo.jac`; an annex inside a
    `foo.impl/` directory maps to `foo.jac` in the parent. Non-annex paths, and
    annexes whose head is not a known project file, are returned unchanged.
    """
    def _head_for(real: str) -> str {
        p = Path(real);
        head: (Path | None) = None;
        name = p.name;
        if name.endswith(".impl.jac") {
            head = p.with_name(name[:-len(".impl.jac")] + ".jac");
        } elif name.endswith(".test.jac") {
            head = p.with_name(name[:-len(".test.jac")] + ".jac");
        }
        # An annex living inside a `<head>.impl/` directory belongs to the
        # `<head>.jac` beside that directory, not to a sibling.
        parent = p.parent;
        if parent.name.endswith(".impl") {
            head = parent.with_name(parent.name[:-len(".impl")] + ".jac");
        }
        if head is not None {
            candidate = _real(str(head));
            if candidate in self._file_set {
                return candidate;
            }
        }
        return real;
    }

    """Forget a deleted project file across the file list, set, and compiled map."""
    def _drop_file(real: str) {
        self._files = [
            f
            for f in self._files
            if _real(f) != real
        ];
        self._file_set.discard(real);
        if real in self._compiled {
            del self._compiled[real];
        }
        self._dir_sig = self._dir_signature();
    }

    """Compile one project file and record the resulting module.

    In `structural` mode the file is only parsed (`parse_str`) -- enough for the
    AST-level structural queries and far cheaper, since it never resolves
    imports or runs the symbol/type passes. Otherwise the full pipeline runs,
    type-checked or not per `type_check`.
    """
    def _compile_one(file: str) {
        try {
            if self.structural {
                mod = self.prog.parse_str(Path(file).read_text(), file);
            } else {
                mod = self.prog.compile(
                    file_path=file, type_check=self.type_check, no_cgen=True
                );
            }
            # Keep the compiled module directly rather than relying on the
            # program hub: hub routing depends on the project's location.
            if mod is not None and mod.loc {
                self._compiled[_real(mod.loc.mod_path)] = mod;
            }
        } except Exception as e {
            # Keep going: one bad file should not blind the agent to the rest.
            _ = e;
        }
    }

    """A directory-mtime signature -- changes when a file is added or removed.

    Editing a file's content does not touch its directory's mtime, so an
    unchanged signature means an incremental refresh is safe.
    """
    def _dir_signature -> dict[str, float] {
        dirs: set[str] = {self._root_real};
        for f in self._files {
            dirs.add(os.path.dirname(_real(f)));
        }
        sig: dict[str, float] = {};
        for d in dirs {
            try {
                sig[d] = os.path.getmtime(d);
            } except OSError as e {
                _ = e;
            }
        }
        return sig;
    }

    """Filter alerts down to those whose file is NOT in the stale set."""
    def _keep_diagnostics(alerts: list[Alert], stale: set[str]) -> list[Alert] {
        out: list[Alert] = [];
        for al in alerts {
            loc = al.loc;
            if loc is None or _real(loc.mod_path) not in stale {
                out.append(al);
            }
        }
        return out;
    }

    def _ensure {
        if not self._loaded {
            self.load();
        }
    }

    """Whether `load` has compiled the project at least once.

    Lets a caller read already-built results (e.g. `diagnostics`) without
    paying for a first compile -- a query that must stay cheap can skip itself
    when the project model is not yet built.
    """
    def is_loaded -> bool {
        return self._loaded;
    }

    """List the project .jac files that were compiled."""
    def files -> list[str] {
        self._ensure();
        return list(self._files);
    }

    #-- internals --------------------------------------------------------
    def _discover -> list[str] {
        found: list[str] = [];
        base = Path(self._root_real);
        if not base.exists() {
            return found;
        }
        for p in sorted(base.rglob("*.jac")) {
            if any([part in _SKIP_DIRS or part.startswith(".") for part in p.parts]) {
                continue;
            }
            name = p.name;
            if name.endswith(".impl.jac") or name.endswith(".test.jac") {
                continue;
            }
            found.append(str(p));
        }
        return found;
    }

    """The compiled modules of the project."""
    def _modules -> list[uni.Module] {
        self._ensure();
        return list(self._compiled.values());
    }

    """Recursively collect every Symbol reachable from a scope."""
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

    """Every Symbol declared anywhere in the project."""
    def _all_syms -> list[uni.Symbol] {
        out: list[uni.Symbol] = [];
        for mod in self._modules() {
            try {
                self._collect_syms(mod.sym_tab, out);
            } except Exception as e {
                _ = e;
            }
        }
        return out;
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
            return str(expr.unparse()).strip();
        } except Exception as e {
            _ = e;
            return "";
        }
    }

    def _doc_of(owner: uni.UniNode) -> str {
        try {
            doc = owner?.doc;
            if doc is not None and doc?.value {
                return str(doc.value).strip().strip('"');
            }
        } except Exception as e {
            _ = e;
        }
        return "";
    }

    """Build a SymbolInfo from a resolved Symbol, or None if it has no decl."""
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
            doc=self._doc_of(owner)
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

    """Find the canonical (non-imported) Symbols matching a name."""
    def _resolve(name: str) -> list[uni.Symbol] {
        hits: list[uni.Symbol] = [];
        seen: set[str] = set();
        for sym in self._all_syms() {
            if sym.sym_name != name {
                continue;
            }
            if getattr(sym, "imported", False) {
                continue;
            }
            decl = sym.decl;
            if decl is None or decl.loc is None {
                continue;
            }
            key = f"{decl.loc.mod_path}:{decl.loc.first_line}";
            if key in seen {
                continue;
            }
            seen.add(key);
            hits.append(sym);
        }
        return hits;
    }

    #-- name-addressed queries ------------------------------------------
    """Look up every project symbol with the given name."""
    def lookup(name: str) -> list[SymbolInfo] {
        out: list[SymbolInfo] = [];
        for sym in self._resolve(name) {
            info = self._info(sym);
            if info is not None {
                out.append(info);
            }
        }
        return out;
    }

    """The first definition of a symbol, or None if it is unknown."""
    def definition(name: str) -> SymbolInfo | None {
        hits = self.lookup(name);
        return hits[0] if hits else None;
    }

    """Every definition and use of a symbol, across the whole project.

    This is the precise answer that replaces a text search: it is computed
    from the symbol table's def/use chains, so it never matches a comment, a
    string, or an unrelated identifier that happens to share the name.
    """
    def references(name: str) -> list[SourceRef] {
        out: list[SourceRef] = [];
        seen: set[str] = set();
        for sym in self._resolve(name) {
            for (role, nodes) in [("def", sym.defn), ("use", sym.uses)] {
                for nd in nodes {
                    loc = nd.loc;
                    if loc is None {
                        continue;
                    }
                    key = f"{loc.mod_path}:{loc.first_line}:{loc.col_start}";
                    if key in seen {
                        continue;
                    }
                    seen.add(key);
                    out.append(
                        SourceRef(
                            file=loc.mod_path,
                            line=loc.first_line,
                            col=loc.col_start,
                            role=role
                        )
                    );
                }
            }
        }
        return out;
    }

    """Distinct files that define or use a symbol."""
    def importers(name: str) -> list[str] {
        files: list[str] = [];
        for ref in self.references(name) {
            if ref.file not in files {
                files.append(ref.file);
            }
        }
        return files;
    }

    """Top-level symbols of one file, or of the whole project if file is empty."""
    def symbols(file: str = "") -> list[SymbolInfo] {
        target = _real(file) if file else "";
        out: list[SymbolInfo] = [];
        for mod in self._modules() {
            try {
                if target and _real(mod.loc.mod_path) != target {
                    continue;
                }
                for sym in mod.sym_tab.names_in_scope.values() {
                    if getattr(sym, "imported", False) {
                        continue;
                    }
                    info = self._info(sym);
                    if info is not None {
                        out.append(info);
                    }
                }
            } except Exception as e {
                _ = e;
            }
        }
        return out;
    }

    #-- structural / OSP queries ----------------------------------------
    """Project archetypes, optionally filtered to one kind (node/walker/...)."""
    def archetypes(kind: str = "") -> list[SymbolInfo] {
        out: list[SymbolInfo] = [];
        for mod in self._modules() {
            try {
                for arch in mod.get_all_sub_nodes(uni.Archetype) {
                    info = self._archetype_info(arch);
                    if info is not None and (not kind or info.kind == kind) {
                        out.append(info);
                    }
                }
            } except Exception as e {
                _ = e;
            }
        }
        return out;
    }

    def _archetype_info(arch: uni.Archetype) -> SymbolInfo | None {
        loc = arch.loc;
        info = SymbolInfo(
            name=arch.name.sym_name,
            kind=self._kind_of(arch),
            file=loc.mod_path if loc else "",
            line=loc.first_line if loc else 0,
            doc=self._doc_of(arch)
        );
        self._fill_archetype(info, arch);
        return info;
    }

    """Every walker entry point in the project, as EntryPoint records."""
    def entry_points -> list[EntryPoint] {
        out: list[EntryPoint] = [];
        for mod in self._modules() {
            try {
                for arch in mod.get_all_sub_nodes(uni.Archetype) {
                    if self._kind_of(arch) != "walker" {
                        continue;
                    }
                    for m in arch.get_methods() {
                        sig = m.signature;
                        if not isinstance(sig, uni.EventSignature) {
                            continue;
                        }
                        node_type = self._expr_str(sig.arch_tag_info) or "any";
                        event = "";
                        try {
                            event = str(sig.event.value);
                        } except Exception as e {
                            _ = e;
                        }
                        mloc = m.loc;
                        out.append(
                            EntryPoint(
                                walker_name=arch.name.sym_name,
                                ability=m.name_ref.sym_name if m.name_ref else "?",
                                node_type=node_type,
                                event=event,
                                file=mloc.mod_path if mloc else "",
                                line=mloc.first_line if mloc else 0
                            )
                        );
                    }
                }
            } except Exception as e {
                _ = e;
            }
        }
        return out;
    }

    """Walker entry points that traverse the given node type.

    A type query, not a search: `walkers_visiting("User")` finds every walker
    ability declared `with User entry`, resolved through the entry signature.
    """
    def walkers_visiting(node_type: str) -> list[EntryPoint] {
        return [
            ep
            for ep in self.entry_points()
            if ep.node_type == node_type or ep.node_type == "any"
        ];
    }

    """The node types a given walker traverses."""
    def nodes_visited_by(walker_name: str) -> list[EntryPoint] {
        return [
            ep
            for ep in self.entry_points()
            if ep.walker_name == walker_name
        ];
    }

    #-- diagnostics ------------------------------------------------------
    """Compiler errors and warnings, optionally filtered to one file."""
    def diagnostics(file: str = "") -> list[Diagnostic] {
        self._ensure();
        target = _real(file) if file else "";
        out: list[Diagnostic] = [];
        for (sev, alerts) in [
            ("error", self.prog.errors_had),
            ("warning", self.prog.warnings_had)
        ] {
            for al in alerts {
                loc = al.loc;
                path = loc.mod_path if loc else "";
                if target and (not path or _real(path) != target) {
                    continue;
                }
                out.append(
                    Diagnostic(
                        file=path,
                        line=loc.first_line if loc else 0,
                        severity=sev,
                        message=str(al.msg)
                    )
                );
            }
        }
        return out;
    }

    """Refresh after an edit and return the diagnostics the edit is responsible for.

    Every diagnostic now in `file` is returned -- the caller just wrote that
    file, so all of it is worth seeing (and its line numbers may have shifted,
    making a per-line diff unreliable). For every *other* project file only
    the diagnostics this edit newly introduced are returned: a dependent
    module the edit broke surfaces, while a dependent's pre-existing error is
    not misattributed to the edit. With no `file` this is a full refresh and
    returns every diagnostic.
    """
    def refresh_and_diff(file: str = "") -> list[Diagnostic] {
        if not file or not self._loaded {
            self.refresh(file);
            return self.diagnostics();
        }
        # Snapshot the pre-edit diagnostics; anything not in this set after the
        # recompile is breakage the edit caused.
        before: set[str] = {_diag_key(d) for d in self.diagnostics()};
        self.refresh(file);
        real = _real(file);
        out: list[Diagnostic] = [];
        for d in self.diagnostics() {
            if _real(d.file) == real or _diag_key(d) not in before {
                out.append(d);
            }
        }
        return out;
    }

    #-- context packing --------------------------------------------------
    """Build a typed context slice around a symbol, for prompt assembly.

    Returns the symbol's definition, the definitions of the types it depends
    on (field types and base classes, up to `depth` of indirection), and the
    list of places it is used -- a minimal, complete neighbourhood the model
    can read instead of whole files.
    """
    def slice_for(name: str, depth: int = 1) -> ContextSlice {
        sl = ContextSlice(query=name);
        sl.target = self.definition(name);
        if sl.target is None {
            return sl;
        }
        sl.uses = [
            r
            for r in self.references(name)
            if r.role == "use"
        ];
        seen: set[str] = {name};
        frontier: list[SymbolInfo] = [sl.target];
        level = 0;
        while frontier and level < depth {
            next_frontier: list[SymbolInfo] = [];
            for info in frontier {
                for dep in self._type_names(info) {
                    if dep in seen {
                        continue;
                    }
                    seen.add(dep);
                    dep_info = self.definition(dep);
                    if dep_info is not None {
                        sl.related.append(dep_info);
                        next_frontier.append(dep_info);
                    }
                }
            }
            frontier = next_frontier;
            level += 1;
        }
        return sl;
    }

    """Extract candidate type identifiers a symbol depends on."""
    def _type_names(info: SymbolInfo) -> list[str] {
        names: set[str] = set();
        for b in info.base_classes {
            for tok in self._idents(b) {
                names.add(tok);
            }
        }
        for f in info.fields {
            if ":" in f {
                for tok in self._idents(f.split(":", 1)[1]) {
                    names.add(tok);
                }
            }
        }
        if info.type_str {
            for tok in self._idents(info.type_str) {
                names.add(tok);
            }
        }
        return list(names);
    }

    """Pull capitalised bare identifiers out of a type expression string."""
    def _idents(text: str) -> list[str] {
        import re;
        out: list[str] = [];
        for tok in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text) {
            word = str(tok);
            if word and word[0].isupper() {
                out.append(word);
            }
        }
        return out;
    }
}
