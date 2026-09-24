import from jaclang.compiler.frontend.roles { Kid }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.runtime.osp_tag { stable_osp_tag }


obj OspSlot {
    has owner: str,
        kind: str,
        ability: str,
        is_entry: bool,
        has_body: bool,
        trigger_names: list[str] = [];
}


obj OspModel {
    has arch_kind: dict[(str, str)] = {},
        tags: dict[(str, int)] = {},
        order: list[str] = [],
        order_index: dict[(str, int)] = {},
        isa: dict[(str, list[str])] = {},
        slots: list[OspSlot] = [],
        collisions: list[tuple[str, str]] = [],
        uses_construct: bool = False;

    def has_event_ability -> bool {
        return len(self.slots) > 0;
    }

    def local_slots -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if s.has_body
        ];
    }

    def has_local_ability -> bool {
        return len(self.local_slots()) > 0;
    }

    def local_index(name: str) -> int {
        return self.order_index.get(name, -1);
    }

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

    def entry_slots(owner: str) -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if (s.owner == owner) and s.is_entry
        ];
    }

    def exit_slots(owner: str) -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if (s.owner == owner) and (not s.is_entry)
        ];
    }
}


def get_osp_model(
    module: uni.Module,
    archetypes: (list[uni.Archetype] | None) = None,
    context: (CodeContext | None) = None,
    native_names: bool = False
) -> OspModel {
    existing = module.gen.native_osp_model if native_names else module.gen.osp_model;
    if existing is not None {
        return existing;
    }
    archs = archetypes
        if archetypes is not None
        else module.get_all_sub_nodes(uni.Archetype);
    model = OspAnalysis.compute(module, archs, context, native_names);
    if native_names {
        module.gen.native_osp_model = model;
    } else {
        module.gen.osp_model = model;
    }
    return model;
}

obj OspAnalysis {
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
        if isinstance(cur, uni.AstSymbolNode) and cur.sym_name {
            return cur.sym_name;
        }
        return None;
    }

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

    static def slot_triggers(
        ability: uni.Ability, native_names: bool = False
    ) -> list[str] {
        if native_names {
            return OspAnalysis.native_slot_triggers(ability);
        }
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

    static def native_slot_triggers(ability: uni.Ability) -> list[str] {
        import from jaclang.compiler.passes.layout_pass {
            native_type_key,
            referenced_native_name
        }
        names: list[str] = [];
        if ability.event_triggers is not None {
            for t in ability.event_triggers {
                for part in native_type_key(t).split("|") {
                    name = part.strip();
                    if name.startswith("type[") and name.endswith("]") {
                        name = name[5:-1];
                    }
                    if name and name not in names {
                        names.append(name);
                    }
                }
            }
            return names;
        }
        _tag_info = None;
        if isinstance(ability.signature, uni.EventSignature) {
            _tag_info = ability.signature.arch_tag_info;
        }
        for head in OspAnalysis.trigger_heads(_tag_info) {
            head_key = referenced_native_name(head) or OspAnalysis.head_name(head);
            if head_key is not None and head_key not in names {
                names.append(head_key);
            }
        }
        return names;
    }

    static def trigger_heads(nd: (uni.UniNode | None)) -> list[uni.UniNode] {
        if nd is None {
            return [];
        }
        if isinstance(nd, uni.TupleVal) {
            heads: list[uni.UniNode] = [];
            for member in nd.values {
                heads.extend(OspAnalysis.trigger_heads(member));
            }
            return heads;
        }
        if isinstance(nd, uni.BinaryExpr)
            and isinstance(nd.op, uni.Token)
            and nd.op.name == Tok.BW_OR {
            return OspAnalysis.trigger_heads(nd.left)
                + OspAnalysis.trigger_heads(nd.right);
        }
        cur = nd;
        while isinstance(cur, uni.FuncCall) {
            cur = cur.target;
        }
        return [cur];
    }

    static def arch_slots(
        arch: uni.Archetype, native_names: bool = False
    ) -> list[OspSlot] {
        out: list[OspSlot] = [];
        _kind = arch.arch_kind;
        _owner = OspAnalysis.arch_key(arch, native_names) if arch.name else None;
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
                    trigger_names=OspAnalysis.slot_triggers(stmt, native_names)
                )
            );
        }
        return out;
    }

    static def arch_key(arch: uni.Archetype, native_names: bool) -> str {
        if native_names {
            import from jaclang.compiler.passes.layout_pass { archetype_native_name }
            return archetype_native_name(arch);
        }
        return arch.name.value;
    }

    static def compute(
        module: uni.Module,
        archetypes: list[uni.Archetype],
        context: (CodeContext | None) = None,
        native_names: bool = False
    ) -> OspModel {
        model = OspModel();
        _archs: dict[(str, uni.Archetype)] = {};
        for arch in archetypes {
            _name = OspAnalysis.arch_key(arch, native_names) if arch.name else None;
            if (_name is None) or (arch.arch_kind is None) or (_name in _archs) {
                continue;
            }
            _archs[_name] = arch;
            model.arch_kind[_name] = arch.arch_kind;
        }

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

        for _name in _archs.keys() {
            model.isa[_name] = OspAnalysis._isa_closure(_name, _archs, native_names);
            model.slots.extend(OspAnalysis.arch_slots(_archs[_name], native_names));
        }
        model.uses_construct = OspAnalysis._uses_construct(module, context);
        return model;
    }

    static def _isa_closure(
        name: str, archs: dict[(str, uni.Archetype)], native_names: bool = False
    ) -> list[str] {
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
                if native_names {
                    import from jaclang.compiler.passes.layout_pass {
                        referenced_native_name
                    }
                    _bn = referenced_native_name(_bc) or _bn;
                }
                if (_bn is not None) and (_bn in archs) and (_bn not in seen) {
                    seen.add(_bn);
                    out.append(_bn);
                    work.append(_bn);
                }
            }
        }
        return out;
    }

    static def _uses_construct(
        module: uni.Module, context: (CodeContext | None)
    ) -> bool {
        roots: list[uni.UniNode] = list(
            ModuleFacts.iter_context_stmts(module, context)
        );
        for stmt in roots {
            work: list[uni.UniNode] = [stmt];
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
                for k in [nd->:Kid:->] {
                    work.append(k);
                }
            }
        }
        return False;
    }
}
