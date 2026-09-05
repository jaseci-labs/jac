"""The native side of the module cache: one registry per program.

`IfaceRegistry` serves a module's type interface from its JIR; this registry
serves the same module's native interface, object and bitcode from the same
entry. There is no second store: a unit's native products live in its module
JIR under MODKEY plus the stamp in their own header, and freshness is the
layered check `SEC_DEPS` already implements, extended by the native digest
column.

Compile-on-demand goes through `JacCompiler.compile` with the native-import
options, so demotion, strictness and the seam report apply unchanged.
"""
import os;
import time;
import from jaclang.compiler.driver.jir {
    NativeStamp,
    SEC_NBITCODE,
    SEC_NIFACE,
    SEC_NOBJ,
    SEC_PLACEMENT,
    cache_mode,
    current_native_stamp,
    get_module_cache_path,
    is_module_cache_valid,
    jir_cacheable_source_path,
    native_section_payload,
    read_section_bytes
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.native_iface { NativeIface }

obj NativeUnitEntry {
    has path: str,
        digest: str,
        iface: NativeIface,
        stamp: NativeStamp,
        source: str = "",
        loaded_at: float = 0.0;
}

"""A module-level native verdict persisted in `SEC_PLACEMENT`: the module
tried to lower natively and failed, so it is served by Python until its
content changes."""
obj NativeVerdict {
    has demoted: bool = False,
        code: str = "",
        detail: str = "";
}

obj NativeUnitRegistry {
    has prog: any,
        entries: dict[str, NativeUnitEntry] = {},
        building: set[str] postinit,
        checking: set[str] postinit,
        not_native: dict[str, tuple] = {},
        recorded_deps: dict[str, dict[str, str]] = {},
        verdicts: dict[str, tuple[tuple, NativeVerdict]] = {};

    def postinit {
        self.building = set();
        self.checking = set();
    }

    def clear {
        self.entries.clear();
        self.not_native.clear();
        self.recorded_deps.clear();
        self.verdicts.clear();
    }

    def forget(path: str) {
        real = os.path.realpath(path);
        self.entries.pop(real, None);
        self.recorded_deps.pop(real, None);
    }

    static def _file_key(path: str) -> (tuple | None) {
        try {
            st = os.stat(path);
            return (st.st_mtime_ns, st.st_size);
        } except OSError {
            return None;
        }
    }

    def _event(name: str) {
        counters = self.prog.analysis.cache_events;
        counters[name] = counters.get(name, 0) + 1;
    }

    def _options -> CompileOptions {
        opts = self.prog.options;
        return opts if opts is not None else CompileOptions();
    }

    def stamp_for(options: (CompileOptions | None) = None) -> NativeStamp {
        opts = options if options is not None else self._options();
        return current_native_stamp(opts.codegen_identity(), opts.effective_triple());
    }

    def _module_jir(resolved: str) -> (tuple[bytes, str] | None) {
        try {
            cache_path = get_module_cache_path(resolved);
            if is_module_cache_valid(resolved, cache_path) {
                return (cache_path.read_bytes(), "", );
            }
        } except Exception {}
        try {
            return self.prog._get_compiler()._sealed_jir_data(resolved);
        } except Exception {
            return None;
        }
    }

    def _entry_fresh(ent: NativeUnitEntry) -> bool {
        import from jaclang.compiler.driver.bccache { discover_annex_files }
        try {
            if os.path.getmtime(ent.path) > ent.loaded_at {
                return False;
            }
            for related in discover_annex_files(ent.path) {
                if os.path.getmtime(related) > ent.loaded_at {
                    return False;
                }
            }
            return True;
        } except OSError {
            return False;
        }
    }

    def _register(resolved: str, iface: NativeIface, stamp: NativeStamp, source: str) -> NativeUnitEntry {
        ent = NativeUnitEntry(
            path=resolved,
            digest=iface.digest(),
            iface=iface,
            stamp=stamp,
            source=source,
            loaded_at=time.time()
        );
        self.entries[resolved] = ent;
        return ent;
    }

    """Record the interface a compile just produced, so the same closure
    reads it back without a disk round trip, with the dependency digests it
    was compiled against."""
    def record(
        path: str,
        iface: NativeIface,
        options: (CompileOptions | None) = None,
        dep_digests: (dict[str, str] | None) = None
    ) -> NativeUnitEntry {
        resolved = os.path.realpath(path);
        if dep_digests is not None {
            self.recorded_deps[resolved] = dict(dep_digests);
        }
        return self._register(resolved, iface, self.stamp_for(options), "compile");
    }

    """The native digests `path` was compiled against, from this program's
    memory first and its JIR otherwise: the plan's agreement check."""
    def recorded_native_deps(path: str) -> list[tuple[str, str]] {
        resolved = os.path.realpath(path);
        live = self.recorded_deps.get(resolved);
        if live is not None {
            return sorted(live.items());
        }
        found = self._module_jir(resolved);
        if found is None {
            return [];
        }
        import from jaclang.compiler.driver.jir { read_native_dep_hashes }
        return read_native_dep_hashes(found[0], found[1]);
    }

    """The native digests of `paths` as this registry knows them now."""
    def dep_digests(paths: list[str]) -> dict[str, str] {
        out: dict[str, str] = {};
        for p in paths {
            real = os.path.realpath(p);
            out[real] = self.known_digest(real);
        }
        return out;
    }

    def _read_from_disk(
        resolved: str, stamp: NativeStamp, check_deps: bool
    ) -> (NativeUnitEntry | None) {
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        (data, base_dir) = found;
        payload = native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp);
        iface = NativeIface.from_bytes(payload);
        if iface is None {
            return None;
        }
        if check_deps and not self.prog.iface_registry()._ndeps_match(data, base_dir) {
            self._event("native_dep_miss");
            return None;
        }
        return self._register(resolved, iface, stamp, "disk");
    }

    """The native interface of `path` for the current codegen identity.

    Served from memory, then from the module JIR when its stamp matches and
    every recorded native dependency digest still holds, else compiled on
    demand. Returns None while the unit is being built higher up the stack
    (a cycle) or when it is not a native unit.
    """
    def ensure(
        path: str,
        compile_on_miss: bool = True,
        options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        resolved = os.path.realpath(path);
        if not jir_cacheable_source_path(resolved) {
            return None;
        }
        stamp = self.stamp_for(options);
        ent = self.entries.get(resolved);
        if ent is not None and ent.stamp.matches(stamp) and self._entry_fresh(ent) {
            return ent;
        }
        if ent is not None {
            del self.entries[resolved];
        }
        if resolved in self.building {
            return None;
        }
        if resolved in self.checking {
            return self._read_from_disk(resolved, stamp, check_deps=False);
        }
        (rebuild, _) = cache_mode();
        if not rebuild {
            self.checking.add(resolved);
            try {
                found = self._read_from_disk(resolved, stamp, check_deps=True);
            } finally {
                self.checking.discard(resolved);
            }
            if found is not None {
                self._event("native_iface_hit");
                return found;
            }
        }
        if not compile_on_miss or not os.path.isfile(resolved) {
            return None;
        }
        if self.not_native.get(resolved) == NativeUnitRegistry._file_key(resolved) {
            return None;
        }
        return self.compile_unit(resolved, options);
    }

    """Compile `path` as a native unit and register its interface."""
    def compile_unit(
        path: str, options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        resolved = os.path.realpath(path);
        if resolved in self.building {
            return None;
        }
        base = options if options is not None else self._options();
        self.building.add(resolved);
        try {
            self._event("native_unit_compile");
            saved = self.prog.options;
            try {
                mod = self.prog.compile(
                    resolved, options=base.clone_for_native_import()
                );
            } finally {
                self.prog.options = saved;
            }
        } except Exception {
            return None;
        } finally {
            self.building.discard(resolved);
        }
        iface = mod.gen.native_iface if (mod is not None and mod.gen) else None;
        if iface is None {
            found = self.entries.get(resolved);
            if found is None {
                key = NativeUnitRegistry._file_key(resolved);
                if key is not None {
                    self.not_native[resolved] = key;
                }
            }
            return found;
        }
        self.not_native.pop(resolved, None);
        return self._register(resolved, iface, self.stamp_for(base), "compile");
    }

    """The digest of a unit already known to this registry, or the digest
    its JIR carries, without compiling anything."""
    def known_digest(path: str) -> str {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is not None {
            return ent.digest;
        }
        found = self._module_jir(resolved);
        if found is None {
            return "";
        }
        payload = native_section_payload(
            read_section_bytes(found[0], SEC_NIFACE), self.stamp_for()
        );
        return NativeIface.read_digest(payload) or "";
    }

    def _section_payload(
        path: str, sec: int, options: (CompileOptions | None) = None
    ) -> (bytes | None) {
        resolved = os.path.realpath(path);
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        return native_section_payload(
            read_section_bytes(found[0], sec), self.stamp_for(options)
        );
    }

    """The relocatable object of `path` under the current stamp, compiling
    on demand. None when the unit has no object for this identity."""
    def object_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None) {
        resolved = os.path.realpath(path);
        live = self._live_gen(resolved);
        if live is not None and live.native_object is not None {
            return live.native_object;
        }
        obj = self._section_payload(resolved, SEC_NOBJ, options);
        if obj is not None {
            return obj;
        }
        if self.compile_unit(resolved, options) is None {
            return None;
        }
        live = self._live_gen(resolved);
        if live is not None and live.native_object is not None {
            return live.native_object;
        }
        return self._section_payload(resolved, SEC_NOBJ, options);
    }

    """The LLVM bitcode of `path` under the current stamp, compiling on
    demand; the whole-program and JIT link modes read this."""
    def bitcode_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None) {
        resolved = os.path.realpath(path);
        live = self._live_gen(resolved);
        if live is not None and live.native_bitcode is not None {
            return live.native_bitcode;
        }
        bc = self._section_payload(resolved, SEC_NBITCODE, options);
        if bc is not None {
            return bc;
        }
        if self.compile_unit(resolved, options) is None {
            return None;
        }
        live = self._live_gen(resolved);
        if live is not None and live.native_bitcode is not None {
            return live.native_bitcode;
        }
        return self._section_payload(resolved, SEC_NBITCODE, options);
    }

    def _live_gen(resolved: str) -> any {
        mod = self.prog.find_module(resolved);
        if mod is not None and mod.gen is not None {
            return mod.gen;
        }
        carrier = self.prog.hub.artifacts.get(resolved);
        return carrier;
    }

    """The module-level native verdict recorded in the JIR's placement
    summary, or None when the module has never been demoted for its current
    content. A content edit changes MODKEY and clears the verdict with it."""
    def verdict_for(path: str) -> (NativeVerdict | None) {
        resolved = os.path.realpath(path);
        key = NativeUnitRegistry._file_key(resolved);
        cached = self.verdicts.get(resolved);
        if cached is not None {
            if cached[0] == key {
                return cached[1];
            }
            del self.verdicts[resolved];
        }
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        verdict = verdict_from_jir(found[0]);
        if verdict is not None and key is not None {
            self.verdicts[resolved] = (key, verdict, );
        }
        return verdict;
    }

    def is_demoted(path: str) -> bool {
        v = self.verdict_for(path);
        return v is not None and v.demoted;
    }

    def demoted_code(path: str) -> str {
        v = self.verdict_for(path);
        return v.code if v is not None else "";
    }

    """Note a demotion for the module's current content. The placement
    summary carries it into `SEC_PLACEMENT` on the next persist."""
    def record_verdict(path: str, code: str, detail: str) -> None {
        resolved = os.path.realpath(path);
        key = NativeUnitRegistry._file_key(resolved);
        if key is not None {
            self.verdicts[resolved] = (
                key,
                NativeVerdict(demoted=True, code=code, detail=detail),
            );
        }
        import from jaclang.compiler.placement.placement { note_native_verdict }
        note_native_verdict(self.prog, resolved, code, detail);
        self.entries.pop(resolved, None);
    }
}

"""The native verdict a JIR's placement summary carries, or None."""
def verdict_from_jir(data: bytes) -> (NativeVerdict | None) {
    raw = read_section_bytes(data, SEC_PLACEMENT);
    if raw is None {
        return None;
    }
    import from jaclang.compiler.placement.placement { summary_from_bytes }
    summary = summary_from_bytes(raw);
    if summary is None or not summary.native_verdict {
        return None;
    }
    return NativeVerdict(
        demoted=True, code=summary.native_verdict_code, detail=summary.native_verdict
    );
}

"""Read a module's native verdict from its module cache without a program:
the pin resolver's path when no compile is in flight."""
def read_native_verdict(path: str) -> (NativeVerdict | None) {
    resolved = os.path.realpath(path);
    try {
        cache_path = get_module_cache_path(resolved);
        if not is_module_cache_valid(resolved, cache_path) {
            return None;
        }
        return verdict_from_jir(cache_path.read_bytes());
    } except Exception {
        return None;
    }
}
