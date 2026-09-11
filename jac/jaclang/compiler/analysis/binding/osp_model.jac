import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.enums { CodeContext, Tokens as Tok }
import from jaclang.compiler.analysis.binding.module_facts { ModuleFacts }
import from jaclang.runtime.osp_tag { stable_osp_tag }

import from jaclang.compiler.analysis.binding.osp_facts { OspModel, OspSlot }

def prepare_osp_model(
    module: uni.Module,
    archetypes: (list[uni.Archetype] | None) = None,
    context: (CodeContext | None) = None
) -> OspModel {
    existing = artifact_for(module).osp_models.get(context);
    if existing is not None {
        return existing;
    }
    archs = archetypes
        if archetypes is not None
        else module.get_all_sub_nodes(uni.Archetype);
    model = OspAnalysis.compute(module, archs, context);
    artifact_for(module).osp_models[context] = model;
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
                for k in nd.kid {
                    work.append(k);
                }
            }
        }
        return False;
    }
}
