import from dataclasses { field }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }


def stable_osp_tag(name: str) -> int {
    _h = 14695981039346656037;
    for _c in name {
        _h = ((_h ^ ord(_c)) * 1099511628211) & 18446744073709551615;
    }
    return _h & 9007199254740991;
}


obj OspSlot {
    has owner: str,
        kind: str,
        ability: str,
        is_entry: bool,
        has_body: bool,
        trigger_names: list[str] = field(default_factory=`list);
}


obj OspModel {
    has arch_kind: dict[(str, str)] = field(default_factory=`dict),
        tags: dict[(str, int)] = field(default_factory=`dict),
        order: list[str] = field(default_factory=`list),
        order_index: dict[(str, int)] = field(default_factory=`dict),
        isa: dict[(str, list[str])] = field(default_factory=`dict),
        slots: list[OspSlot] = field(default_factory=`list),
        collisions: list[(str, str)] = field(default_factory=`list),
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
        if (cur is not None) and cur?.sym_name {
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
            model.isa[_name] = OspAnalysis._isa_closure(_name, _archs);
            model.slots.extend(OspAnalysis.arch_slots(_archs[_name]));
        }
        model.uses_construct = OspAnalysis._uses_construct(module, context);
        return model;
    }

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
