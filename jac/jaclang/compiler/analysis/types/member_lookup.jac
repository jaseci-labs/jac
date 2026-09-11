import from jaclang.compiler.analysis.binding.bindings { def_insert }
import from jaclang.compiler.ir.types.nodes { ClassType, FunctionType, TypeBase }
import from jaclang.compiler.ir.schema {
    Symbol,
    NameAtom,
    Archetype,
    AstSymbolNode,
    Ability,
    Module,
    UniScopeNode
}

def lookup_member_symbol(
    class_type: ClassType, member: str, r_overloaded: list | None = None
) -> (Symbol | None) {
    import from jaclang.compiler.ir.syntax.nodes {
        Ability,
        Archetype,
        Assignment,
        AtomTrailer,
        FuncSignature,
        ParamVar
    }
    import from jaclang.compiler.analysis.types.type_utils { collect_member_syms }
    for cls in class_type.shared.mro {
        all_syms = collect_member_syms(cls.shared.symbol_table, member);
        if all_syms {
            if r_overloaded is not None and len(all_syms) > 1 {
                r_overloaded.extend(all_syms[1:]);
            }
            return all_syms[0];
        }
    }

    for cls in class_type.shared.mro {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, Archetype) {
            continue;
        }
        is_class = arch.arch_type.name == 'KW_CLASS';

        for method_name in ('init', '__post_init__') {
            method_sym = arch.lookup(method_name, deep=False);
            if not method_sym or not isinstance(method_sym.decl.name_of, Ability) {
                continue;
            }
            method_ability = method_sym.decl.name_of;

            if (
                isinstance(method_ability.signature, FuncSignature)
                and method_ability.signature.params
            ) {
                for param in method_ability.signature.params {
                    if not isinstance(param, ParamVar) {
                        continue;
                    }
                    if param.name.value == member and param.name.value != 'self' {
                        def_insert(arch, param.name, access_spec=arch);
                        return arch.lookup(member, deep=False);
                    }
                }
            }

            for trailer in method_ability.get_all_sub_nodes(AtomTrailer) {
                if not (trailer.parent and isinstance(trailer.parent, Assignment)) {
                    continue;
                }
                if trailer != trailer.parent.target[0] {
                    continue;
                }

                if not is_class and trailer.parent.type_tag is None {
                    continue;
                }
                chain = trailer.as_attr_list;
                if (
                    len(chain) >= 2
                    and chain[0].sym_name == 'self'
                    and chain[1].sym_name == member
                ) {
                    def_insert(arch, chain[1], access_spec=arch);
                    return arch.lookup(member, deep=False);
                }
            }
        }
    }
    return None;
}
