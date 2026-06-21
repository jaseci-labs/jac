"""Backend-neutral Object-Spatial Programming (OSP) compile-time analysis.

Single source of the OSP "program facts" every backend needs to lower
`spawn` / `visit` / `connect` / `report` through the portable `osp_kernel.jac`:
the archetype-kind map (walker/node/edge), each archetype's globally-stable type
tag, the subtype `is_a` relation, the per-archetype entry/exit dispatch slots,
and whether the module uses any OSP construct. The native (LLVM) and ECMAScript
backends both consume one `OspModel` (held on `CodeGenTarget.osp_model`); neither
derives or stores these facts itself.

The runtime *traversal algorithm* lives in `osp_kernel.jac`; this module only
derives the per-program tables that feed it.
"""
import from dataclasses { field }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }


"""Globally-stable OSP type tag: deterministic 64-bit FNV-1a hash of the
archetype name, masked to a non-negative 53-bit value (so it is never the -1
UNTYPED / generic-edge sentinel). The single definition shared by every backend,
so a shared archetype gets the SAME tag wherever it is compiled -- the
cross-module materialization #6642 needs, without position-based numbering.

53 bits, not the full i63: the ECMAScript backend stores tags as a JS `Number`
(IEEE-754 double, 53-bit mantissa), which silently rounds any integer above
2^53. Keeping every tag <= 2^53-1 makes it exactly representable in JS, so the
compile-time collision check in `OspAnalysis.compute` operates on the SAME values
the JS runtime sees -- otherwise two names whose i63 hashes differ only in their
low bits would pass the Python check yet collide (and mis-dispatch) in JS. The
native (i64) backend is unaffected. 53 bits still leaves collisions
astronomically unlikely for any realistic archetype count."""
def stable_osp_tag(name: str) -> int {
    _h = 14695981039346656037;
    for _c in name {
        _h = ((_h ^ ord(_c)) * 1099511628211) & 18446744073709551615;
    }
    return _h & 9007199254740991;
}


"""One OSP dispatch slot: an event ability (`can <ability> with <T> entry/exit`)
on `owner` (kind walker/node/edge). `trigger_names` are the archetype names the
ability fires on ([] = untyped, fires on any location). `has_body` is False for a
body-less server-walker RPC stub, which is not a local dispatch slot."""
obj OspSlot {
    has owner: str,
        kind: str,
        ability: str,
        is_entry: bool,
        has_body: bool,
        trigger_names: list[str] = field(default_factory=`list);
}


"""The derived OSP facts for one compile -- the single store both backends read
(held on `CodeGenTarget.osp_model`). Built by `OspAnalysis.compute`."""
obj OspModel {
    has arch_kind: dict[(str, str)] = field(default_factory=`dict),
        tags: dict[(str, int)] = field(default_factory=`dict),
        order: list[str] = field(default_factory=`list),
        order_index: dict[(str, int)] = field(default_factory=`dict),
        isa: dict[(str, list[str])] = field(default_factory=`dict),
        slots: list[OspSlot] = field(default_factory=`list),
        collisions: list[(str, str)] = field(default_factory=`list),
        uses_construct: bool = False;

    """True when any OSP event ability exists (a walker/node/edge declares
    `with T entry/exit`), body-less RPC stubs included -- the native gate for
    participating in OSP."""
    def has_event_ability -> bool {
        return len(self.slots) > 0;
    }

    """Slots with a local body -- the abilities that actually run through the
    kernel (a body-less `with T entry;` is a server-walker RPC stub, not a local
    dispatch slot)."""
    def local_slots -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if s.has_body
        ];
    }

    """True when any OSP event ability has a local body -- the ECMAScript gate
    for emitting local kernel descriptors."""
    def has_local_ability -> bool {
        return len(self.local_slots()) > 0;
    }

    """Dense local index of `name` in `order` (the per-compile descriptor / is_a
    table index), or -1 when `name` is not a tagged OSP archetype. O(1) via the
    `order_index` reverse map built once in `compute` (called per ancestor of
    every archetype, so a per-call `order.index()` scan would be O(N^2))."""
    def local_index(name: str) -> int {
        return self.order_index.get(name, -1);
    }

    """Stable trigger tags for a slot: [-1] (UNTYPED) when the trigger is
    untyped, else one tag per trigger archetype (-1 for an unknown name)."""
    def trigger_tags(slot: OspSlot) -> list[int] {
        if not slot.trigger_names {
            return [-1];
        }
        out: list[int] = [];
        for _n in slot.trigger_names {
            out.append(self.tags.get(_n, -1));
        }
        return out;
    }

    """The entry dispatch slots owned by `owner`, in declaration order."""
    def entry_slots(owner: str) -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if (s.owner == owner) and s.is_entry
        ];
    }

    """The exit dispatch slots owned by `owner`, in declaration order."""
    def exit_slots(owner: str) -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if (s.owner == owner) and (not s.is_entry)
        ];
    }
}


"""Derives an `OspModel`. Stateless; one static entry point so the derivation
lives in exactly one place."""
obj OspAnalysis {
    """Resolve a trigger / base type-reference node to its head archetype name
    (walks `FuncCall` / `AtomTrailer` to the head `Name`). The single fallback
    used when the checker did not record resolved trigger names (e.g. a
    JIR-loaded tree), replacing the per-backend `_get_name` / `_ref_head_name`
    copies."""
    static def head_name(nd: (uni.UniNode | None)) -> (str | None) {
        cur = nd;
        while True {
            if isinstance(cur, uni.FuncCall) {
                cur = cur.target;
            } elif isinstance(cur, uni.AtomTrailer) {
                cur = cur.target;
            } else {
                break;
            }
        }
        if isinstance(cur, uni.Name) {
            return cur.value;
        }
        if (cur is not None) and cur?.sym_name {
            return cur.sym_name;
        }
        return None;
    }

    """Flatten an OSP ability trigger (`with <T> entry`) into archetype names.
    None -> [] (untyped); a tuple/union -> each member; a plain type -> [name]."""
    static def flatten_trigger(nd: (uni.UniNode | None)) -> list[str] {
        if nd is None {
            return [];
        }
        names: list[str] = [];
        if isinstance(nd, uni.TupleVal) {
            for member in nd.values {
                names.extend(OspAnalysis.flatten_trigger(member));
            }
            return names;
        }
        head = OspAnalysis.head_name(nd);
        if head is not None {
            names.append(head);
        }
        return names;
    }

    """Resolved trigger archetype names for an event ability: the checker-resolved
    names (`Ability.event_trigger_type_names`, unions split / `type[X]` unwrapped)
    when available, else the AST fallback."""
    static def slot_triggers(ability: uni.Ability) -> list[str] {
        trigs = ability.event_trigger_type_names();
        if trigs is None {
            _tag_info = None;
            if isinstance(ability.signature, uni.EventSignature) {
                _tag_info = ability.signature.arch_tag_info;
            }
            trigs = OspAnalysis.flatten_trigger(_tag_info);
        }
        return trigs;
    }

    """OSP event abilities declared directly in `arch`'s body, as `OspSlot`s."""
    static def arch_slots(arch: uni.Archetype) -> list[OspSlot] {
        out: list[OspSlot] = [];
        _kind = arch.arch_kind;
        _owner = arch.name.value if arch.name else None;
        if (_kind is None) or (_owner is None) or (arch.body is None) {
            return out;
        }
        for stmt in arch.body {
            if (not isinstance(stmt, uni.Ability))
            or (not isinstance(stmt.signature, uni.EventSignature)) {
                continue;
            }
            _ability = stmt.name_ref.sym_name if stmt.name_ref else None;
            if _ability is None {
                continue;
            }
            out.append(
                OspSlot(
                    owner=_owner,
                    kind=_kind,
                    ability=_ability,
                    is_entry=(stmt.signature.event.name == Tok.KW_ENTRY),
                    has_body=(stmt.body is not None),
                    trigger_names=OspAnalysis.slot_triggers(stmt)
                )
            );
        }
        return out;
    }

    """Derive the OSP facts for `module` over `archetypes` (the caller assembles
    the set: native = local + imported OSP archetypes; ES = local OSP
    archetypes). `context` bounds the construct scan (native passes NATIVE; ES
    leaves it None as it does not consume `uses_construct`). Non-OSP archetypes
    (`arch_kind is None`) are ignored; names are de-duplicated, first occurrence
    winning."""
    static def compute(
        module: uni.Module,
        archetypes: list[uni.Archetype],
        context: (CodeContext | None) = None
    ) -> OspModel {
        model = OspModel();
        _archs: dict[(str, uni.Archetype)] = {};
        for arch in archetypes {
            _name = arch.name.value if arch.name else None;
            if (_name is None) or (arch.arch_kind is None) or (_name in _archs) {
                continue;
            }
            _archs[_name] = arch;
            model.arch_kind[_name] = arch.arch_kind;
        }
        # Stable content-hash tags + dense order (sorted -> deterministic, and a
        # library and any importer agree). Astronomically-rare hash collisions are
        # recorded (not assigned) so the caller fails loudly instead of
        # mis-dispatching.
        _by_tag: dict[(int, str)] = {};
        for _name in sorted(_archs.keys()) {
            _tag = stable_osp_tag(_name);
            if _tag in _by_tag {
                model.collisions.append((_name, _by_tag[_tag]));
                continue;
            }
            _by_tag[_tag] = _name;
            model.tags[_name] = _tag;
            model.order_index[_name] = len(model.order);
            model.order.append(_name);
        }
        # Subtype is_a closure over the OSP set; dispatch slots per archetype.
        for _name in _archs.keys() {
            model.isa[_name] = OspAnalysis._isa_closure(_name, _archs);
            model.slots.extend(OspAnalysis.arch_slots(_archs[_name]));
        }
        model.uses_construct = OspAnalysis._uses_construct(module, context);
        return model;
    }

    """Names an archetype `is-a`: itself plus every OSP ancestor reachable through
    `base_classes`, restricted to OSP archetypes present in `archs`."""
    static def _isa_closure(name: str, archs: dict[(str, uni.Archetype)]) -> list[str] {
        out: list[str] = [name];
        seen: set[str] = set();
        seen.add(name);
        work: list[str] = [name];
        while work {
            _cur = work.pop();
            _arch = archs.get(_cur);
            if (_arch is None) or (not _arch.base_classes) {
                continue;
            }
            for _bc in _arch.base_classes {
                _bn = OspAnalysis.head_name(_bc);
                if (_bn is not None) and (_bn in archs) and (_bn not in seen) {
                    seen.add(_bn);
                    out.append(_bn);
                    work.append(_bn);
                }
            }
        }
        return out;
    }

    """True when `module` USES an OSP construct -- an edge connect (`++>`), a
    `spawn`, a `visit`, or an edge ref (`[-->]`) -- in its `context` statements.
    Annex and variant bodies are merged into the module's own tree, so iterating
    its context statements already covers impl/variant-defined usage. Distinct
    from declaring OSP archetypes: usage is what requires the kernel + adjacency
    at runtime."""
    static def _uses_construct(
        module: uni.Module, context: (CodeContext | None)
    ) -> bool {
        roots: list = list(ModuleCodegenPass.iter_context_stmts(module, context));
        for stmt in roots {
            work: list = [stmt];
            while work {
                nd = work.pop();
                if isinstance(nd, (uni.ConnectOp, uni.VisitStmt, uni.EdgeOpRef)) {
                    return True;
                }
                if isinstance(nd, uni.BinaryExpr)
                and isinstance(nd.op, uni.Token)
                and (nd.op.name == Tok.KW_SPAWN) {
                    return True;
                }
                for k in nd.kid {
                    work.append(k);
                }
            }
        }
        return False;
    }
}
