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
import json;
import zlib;
import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.passes { Alert }
import from jaclang.jac0core.jir {
    SEC_SYMINDEX,
    SECTIONS_MAGIC,
    HEADER_SIZE,
    create_header,
    parse_header,
    write_sections,
    read_sections,
    get_module_cache_path
}
import from jaclang.jac0core.bccache { discover_annex_files }
import from jaclang.jac0core.ext_registry {
    ANNEX_SUFFIXES,
    ANNEX_FOLDER,
    IMPL_SUFFIX,
    is_annex
}

# Directories never worth compiling -- generated output, vendored deps, VCS.
glob _SKIP_DIRS: set[str] = {
         "__pycache__",
         ".git",
         ".venv",
         "venv",
         "node_modules",
         "build",
         "dist",
         ".mypy_cache",
         ".pytest_cache"
     },
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

    """Rebuild a SymbolInfo from its `to_dict` form (e.g. a cached index)."""
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
            is_genai=bool(d.get("is_genai", False))
        );
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

    """Rebuild an EntryPoint from its `to_dict` form (e.g. a cached index)."""
    static def from_dict(d: dict) -> EntryPoint {
        return EntryPoint(
            walker_name=str(d.get("walker_name", "")),
            ability=str(d.get("ability", "")),
            node_type=str(d.get("node_type", "")),
            event=str(d.get("event", "")),
            file=str(d.get("file", "")),
            line=int(d.get("line", 0))
        );
    }
}


# Bump on any change to the structural index's serialized shape, so a stale
# on-disk index from an older `CodeIntelligence` is rejected rather than
# mis-decoded. The JIR header already invalidates on jaclang/Python version
# change; this guards the index payload's own schema.
glob _INDEX_SCHEMA: int = 1;


"""A flat, serializable structural index of one module.

Holds exactly what the parse-only structural queries need -- the module's
archetypes (with their fields, member signatures, and base classes) and walker
entry points -- as plain `SymbolInfo` / `EntryPoint` records with no
cross-module pointers. This is the unit `CodeIntelligence` persists to and
restores from the JIR `SEC_SYMINDEX` section so a cold start can answer
`project_map` and friends without re-running the semantic pipeline.
"""
obj ModuleIndex {
    has archetypes: list[SymbolInfo] = [],
        entry_points: list[EntryPoint] = [];

    """Serialize to a JSON-friendly dict, tagged with the index schema version."""
    def to_dict -> dict {
        return {
            "schema": _INDEX_SCHEMA,
            "archetypes": [a.to_dict() for a in self.archetypes],
            "entry_points": [e.to_dict() for e in self.entry_points]
        };
    }

    """Rebuild from a `to_dict` form, or None if the schema version mismatches."""
    static def from_dict(d: dict) -> ModuleIndex | None {
        if int(d.get("schema", 0)) != _INDEX_SCHEMA {
            return None;
        }
        return ModuleIndex(
            archetypes=[SymbolInfo.from_dict(x) for x in d.get("archetypes", [])],
            entry_points=[EntryPoint.from_dict(x) for x in d.get("entry_points", [])]
        );
    }
}


#-- structural index cache (cross-run) ---------------------------------------
# A module's parse-only structural index is persisted as a JIR file carrying a
# single `SEC_SYMINDEX` TLV section (no AST payload), so a later run can serve
# `project_map`/structural queries without re-parsing. The cache reuses the JIR
# header + section machinery; it lives at a `.symidx.jir` sibling of the module's
# bytecode JIR so the two writers never clobber each other. Freshness is keyed
# on the source's content hash (header `source_content_hash`), not mtime: a
# parse-only index depends only on its own source and spliced annex files, so
# no transitive-dependency tracking is needed.
"""The on-disk cache path for a module's structural index."""
def _index_cache_path(file: str) -> Path {
    base = get_module_cache_path(file);
    return base.with_name(base.stem + ".symidx.jir");
}


"""CRC32 over a module's source plus its spliced annex files.

Both `.impl.jac` and `.test.jac` annexes are folded in, since the compiler
splices them into the module and they can contribute archetypes. A change in
any of them must invalidate the cached index. Returns -1 if the source cannot
be read, which never matches a stored hash (so the cache misses safely).
"""
def _combined_source_hash(file: str) -> int {
    crc = 0;
    try {
        with open(file, 'rb') as f {
            crc = zlib.crc32(f.read(), crc);
        }
    } except OSError as e {
        _ = e;
        return -1;
    }
    annexes: list[str] = [];
    for suffix in ANNEX_SUFFIXES {
        try {
            annexes.extend(discover_annex_files(file, suffix));
        } except Exception as e {
            _ = e;
        }
    }
    for annex in sorted(set(annexes)) {
        try {
            with open(annex, 'rb') as f {
                crc = zlib.crc32(f.read(), crc);
            }
        } except OSError as e {
            _ = e;
        }
    }
    return crc & 0xFFFFFFFF;
}


"""Read a module's cached structural index, or None if absent/stale/incompatible.

Misses (returns None) when: the cache file is missing, its header is from an
incompatible compiler/Python, the stored content hash no longer matches the
source + annexes, or the section/schema cannot be decoded.
"""
def _read_index_cache(file: str) -> ModuleIndex | None {
    path = _index_cache_path(file);
    if not path.exists() {
        return None;
    }
    try {
        data = path.read_bytes();
        header = parse_header(data);
        if header is None or not header.is_compatible() {
            return None;
        }
        if header.source_content_hash != _combined_source_hash(file) {
            return None;
        }
        magic: any = SECTIONS_MAGIC;
        pos = data.find(magic, HEADER_SIZE);
        if pos < 0 {
            return None;
        }
        sections = read_sections(data, pos + len(magic));
        raw = sections.get(SEC_SYMINDEX);
        if raw is None {
            return None;
        }
        return ModuleIndex.from_dict(json.loads(bytes(raw).decode('utf-8')));
    } except Exception as e {
        _ = e;
        return None;
    }
}


"""Atomically write a module's structural index to its cache file.

The JIR carries only the `SEC_SYMINDEX` section (an empty AST payload, like a
precompiled bundle); the header's `source_content_hash` keys freshness. Any
failure is swallowed -- the cache is an optimisation, never a correctness
dependency.
"""
def _write_index_cache(file: str, idx: ModuleIndex) {
    try {
        payload = json.dumps(idx.to_dict()).encode('utf-8');
        header = create_header(
            source_hash=_combined_source_hash(file),
            node_count=0,
            symbol_count=len(idx.archetypes),
            string_pool_size=0
        );
        empty_payload = zlib.compress(bytes(1), 1);
        blob = header.to_bytes() + empty_payload + write_sections(
            {SEC_SYMINDEX: payload}
        );
        path = _index_cache_path(file);
        path.parent.mkdir(parents=True, exist_ok=True);
        tmp = path.with_suffix(".tmp");
        tmp.write_bytes(blob);
        tmp.rename(path);
    } except Exception as e {
        _ = e;
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
        # Lazy mode: `load` builds only the cheap, cross-run-cached structural
        # index (parse-only), and the full type-checked pipeline is deferred
        # until the first query that needs symbol tables or diagnostics. So a
        # session that only reads the structural map (`project_map`, walkers)
        # never pays the semantic-analysis cost, and a warm cache makes that
        # startup nearly free; the full build still runs, once, on demand.
        # Ignored when `structural` is set (that mode never upgrades to full).
        lazy: bool = False,
        # Optional observer invoked after every compile (`load`/`refresh`) with
        # a stats dict {op, file, recompiled, cached, total, ms}. Lets a caller
        # (the `jac ai` live view) surface when code intelligence recompiles and
        # how much it touched, without this facade knowing anything about rendering.
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
        # In `structural` mode, each module's flat index keyed by real path --
        # populated from the on-disk `SEC_SYMINDEX` cache on a hit, or built
        # from a fresh parse on a miss. Structural queries read from here so a
        # cache hit needs no AST. Empty (and unused) in full-compile mode.
        self._index: dict[str, ModuleIndex] = {};
        # Lazy mode: whether the full type-checked pipeline has run yet. Until
        # it has, only the structural index is available; the first type query
        # flips this via `_ensure_full`.
        self._full_compiled: bool = False;
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
        self._index = {};
        # A fresh load rebuilds only the structural index in lazy mode; the full
        # pipeline re-defers to the next type query.
        self._full_compiled = False;
        # In structural (and lazy) mode a file is either re-parsed (a cache miss)
        # or served from its on-disk index (a hit); split the counts so the
        # `on_event` observer can show the cross-run win. In full mode every file
        # is compiled, so `parsed` is the whole project and `cached` is zero.
        parsed = 0;
        cached = 0;
        for f in self._files {
            if self._compile_one(f) {
                cached += 1;
            } else {
                parsed += 1;
            }
        }
        self._dir_sig = self._dir_signature();
        self._loaded = True;
        self._emit("load", "", parsed, t0, cached);
    }

    """Notify the `on_event` observer that a compile just happened (if set).

    `recompiled` is how many modules were actually parsed/compiled; `cached`
    is how many were served from the on-disk structural index (structural mode
    only, else zero).
    """
    def _emit(op: str, file: str, recompiled: int, t0: float, cached: int = 0) {
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
                    "cached": cached,
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
        # Strip the annex suffix only, preserving any codespace variant
        # (e.g. foo.cl.impl.jac -> foo.cl.jac).
        for asuf in ANNEX_SUFFIXES {
            if name.endswith(asuf) {
                head = p.with_name(name[:-len(asuf)] + ".jac");
                break;
            }
        }
        # An annex living inside a `<head>.impl/` directory belongs to the
        # `<head>.jac` beside that directory, not to a sibling.
        parent = p.parent;
        impl_folder = ANNEX_FOLDER[IMPL_SUFFIX];
        if parent.name.endswith(impl_folder) {
            head = parent.with_name(parent.name[:-len(impl_folder)] + ".jac");
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
        if real in self._index {
            del self._index[real];
        }
        self._dir_sig = self._dir_signature();
    }

    """Compile (or restore) one project file. Returns whether it was cache-served.

    In `structural` mode -- and in `lazy` mode before the full pipeline has run
    -- the module's flat index is restored from the on-disk `SEC_SYMINDEX` cache
    when the source is unchanged (returns True, no parse), else parsed and cached
    (returns False). Full mode (and lazy after upgrade) runs the type-checked-or-
    not pipeline and returns False -- it needs symbol tables the cache omits.
    """
    def _compile_one(file: str) -> bool {
        if self.structural or (self.lazy and not self._full_compiled) {
            return self._index_one(file);
        }
        self._full_compile_one(file);
        return False;
    }

    """Run the full pipeline for one file and record its module and index.

    Keeps the compiled module directly (rather than via the program hub, whose
    routing depends on the project's location) and refreshes the file's
    structural index from the now-fully-built AST.
    """
    def _full_compile_one(file: str) {
        try {
            mod = self.prog.compile(
                file_path=file, type_check=self.type_check, no_cgen=True
            );
            if mod is not None and mod.loc {
                key = _real(mod.loc.mod_path);
                self._compiled[key] = mod;
                try {
                    self._index[key] = self._build_index(mod);
                } except Exception as e {
                    _ = e;
                }
            }
        } except Exception as e {
            # Keep going: one bad file should not blind the agent to the rest.
            _ = e;
        }
    }

    """Upgrade a lazy load to the full type-checked pipeline, once, on demand.

    A no-op unless `lazy` is set and the upgrade has not happened. Runs a clean
    full build of every project file -- equivalent to a non-lazy `load` -- so
    symbol tables, def/use chains, and type diagnostics become available. The
    hub and type system are reset first so the full build does not reuse the
    parse-only modules left by the structural load.
    """
    def _ensure_full {
        if not self.lazy or self._full_compiled {
            return;
        }
        self._ensure();
        t0 = time.time();
        self._full_compiled = True;
        self.prog.errors_had = [];
        self.prog.warnings_had = [];
        try {
            self.prog.clear_type_system(clear_hub=True);
        } except Exception as e {
            _ = e;
        }
        self._compiled = {};
        self._index = {};
        for f in self._files {
            self._full_compile_one(f);
        }
        self._emit("typecheck", "", len(self._files), t0);
    }

    """Restore or build one module's structural index. Returns True on a cache hit.

    Tries the on-disk `SEC_SYMINDEX` cache first; on a hit the index is restored
    with no parse. On a miss the file is parsed, its index built off the AST and
    written back to the cache for the next run.
    """
    def _index_one(file: str) -> bool {
        real = _real(file);
        cached = _read_index_cache(file);
        if cached is not None {
            self._index[real] = cached;
            return True;
        }
        try {
            mod = self.prog.parse_str(Path(file).read_text(), file);
            if mod is not None and mod.loc {
                key = _real(mod.loc.mod_path);
                self._compiled[key] = mod;
                idx = self._build_index(mod);
                self._index[key] = idx;
                _write_index_cache(file, idx);
            }
        } except Exception as e {
            # Keep going: one bad file should not blind the agent to the rest.
            _ = e;
        }
        return False;
    }

    """Build a module's flat structural index from its parsed AST."""
    def _build_index(mod: uni.Module) -> ModuleIndex {
        idx = ModuleIndex();
        try {
            for arch in mod.get_all_sub_nodes(uni.Archetype) {
                info = self._archetype_info(arch);
                if info is not None {
                    idx.archetypes.append(info);
                }
            }
        } except Exception as e {
            _ = e;
        }
        try {
            idx.entry_points = self._module_entry_points(mod);
        } except Exception as e {
            _ = e;
        }
        return idx;
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
            if is_annex(name) {
                continue;
            }
            found.append(str(p));
        }
        return found;
    }

    """The fully-compiled modules of the project.

    Reading the AST modules implies a type query, so this triggers the lazy
    full-pipeline upgrade (a no-op outside lazy mode).
    """
    def _modules -> list[uni.Module] {
        self._ensure();
        self._ensure_full();
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
    """Project archetypes, optionally filtered to one kind (node/walker/...).

    In structural mode these come from the (possibly cache-restored) flat index
    rather than the AST, so a cold start with a warm cache pays no parse.
    """
    def archetypes(kind: str = "") -> list[SymbolInfo] {
        out: list[SymbolInfo] = [];
        if self.structural or self.lazy {
            # Served from the flat index -- in lazy mode this deliberately does
            # NOT trigger the full pipeline, so a map query stays cheap.
            self._ensure();
            for idx in self._index.values() {
                for info in idx.archetypes {
                    if not kind or info.kind == kind {
                        out.append(info);
                    }
                }
            }
            return out;
        }
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

    """Every walker entry point in the project, as EntryPoint records.

    In structural mode these come from the (possibly cache-restored) flat index;
    otherwise they are read straight off each compiled module's AST.
    """
    def entry_points -> list[EntryPoint] {
        out: list[EntryPoint] = [];
        if self.structural or self.lazy {
            # Served from the flat index; stays cheap in lazy mode (no upgrade).
            self._ensure();
            for idx in self._index.values() {
                out.extend(idx.entry_points);
            }
            return out;
        }
        for mod in self._modules() {
            out.extend(self._module_entry_points(mod));
        }
        return out;
    }

    """Walker entry points declared in a single module, read off its AST."""
    def _module_entry_points(mod: uni.Module) -> list[EntryPoint] {
        out: list[EntryPoint] = [];
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
        # Diagnostics are a type query: parse-only never reports the semantic
        # errors/warnings the agent's write-feedback loop relies on.
        self._ensure_full();
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
