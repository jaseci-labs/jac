"""Enum pre-pass: Q6 verdict (ENUM_AS_ENUM vs ENUM_AS_CONSTS) for all enums.

Single AST walk over file_ast produces:
  EnumVerdicts.verdicts: dict[int, Idiom]  — id(c_enum) → ENUM_AS_ENUM | ENUM_AS_CONSTS | TIER_B
  EnumVerdicts.name_map: dict[int, dict[str, int]]  — id(c_enum) → {enumerator_name: value}

v1 heuristic for ENUM_AS_ENUM:
  - named enum
  - all enumerator values are implicit (auto-sequential int) OR explicit simple int literals
  - no duplicate values
  - no bitwise/arithmetic expressions in value definitions (the value resolver in
    `_enumerator_value` rejects these — anything non-simple forces ENUM_AS_CONSTS)
  - no arithmetic/bitwise operation with an enumerator name at a use site anywhere in
    the translation unit (`_collect_int_use_names`): a named enum whose members are
    consumed as integers (flags, masks, `x | FLAG`) is demoted to ENUM_AS_CONSTS so the
    integer semantics survive.

Everything else → ENUM_AS_CONSTS, subject to glob-name collision check.
Collision check: an ENUM_AS_CONSTS enum whose enumerator name collides with ANY existing
module-level identifier — another lowered enum's constant, or a top-level C function /
variable / typedef name (`_collect_tu_names`) — demotes to TIER_B ("enumerator name
collides with an existing module global"). Seeding the TU names up front makes the check
order-independent, so an enum constant clashing with a function declared later still
demotes instead of silently shadowing it at module scope.
"""

import from pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Idiom, Tier, Mechanism, NodeTag, TagTable }
import from jaclang.compiler.c2jac.c_common { parse_c_int }

# Binary ops whose operands are being consumed as plain integers. An enumerator
# appearing as an operand of one of these is evidence the program relies on the
# enum's integer value, not its symbolic identity → lower it to consts.
glob _INT_USE_BINOPS: set[str] = {
         "|",
         "&",
         "^",
         "<<",
         ">>",
         "+",
         "-",
         "*",
         "/",
         "%"
     };

obj EnumVal {
    has value: int,
        simple: bool;
}

obj EnumVerdicts {
    has verdicts: dict[int, Idiom],  # id(c_enum) → lowering verdict
        name_map: dict[int, dict[str, int]],  # id(c_enum) → {name: value}
        reasons: dict[int, str];  # id(c_enum) → Tier-B reason (for the Tier-B comments)

    def init {
        self.verdicts = {};
        self.name_map = {};
        self.reasons = {};
    }
}

def _collect_tu_names(file_ast: object) -> set[str] {
    # Every top-level identifier the lowered module already binds: C function and
    # global-variable names (Decl / FuncDef) plus typedef names. An ENUM_AS_CONSTS
    # enumerator that collides with one of these would shadow it once hoisted to
    # module scope, so they pre-seed the collision set.
    names: set[str] = set();
    ext = getattr(file_ast, "ext");
    if ext is None {
        return names;
    }
    for entry in ext {
        if isinstance(entry, c_ast.FuncDef) {
            decl = getattr(entry, "decl");
            nm = getattr(decl, "name") if decl is not None else None;
            if isinstance(nm, str) {
                names.add(str(nm));
            }
        } elif isinstance(entry, c_ast.Decl) {
            nm = entry.name;
            if isinstance(nm, str) {
                names.add(str(nm));
            }
        } elif isinstance(entry, c_ast.Typedef) {
            nm = entry.name;
            if isinstance(nm, str) {
                names.add(str(nm));
            }
        }
    }
    return names;
}

def _collect_int_use_names(nd: object, names: set[str]) {
    # Walk the whole TU collecting identifier names used as operands of an
    # arithmetic/bitwise binary op, or of a bitwise-not. An ENUM_AS_ENUM candidate
    # whose enumerator appears here is being used as an integer and is demoted.
    if isinstance(nd, c_ast.BinaryOp) {
        if nd.op in _INT_USE_BINOPS {
            for operand in (nd.left, nd.right) {
                if isinstance(operand, c_ast.ID) {
                    names.add(operand.name);
                }
            }
        }
    }
    if isinstance(nd, c_ast.UnaryOp) {
        if nd.op == "~" {
            if isinstance(nd.expr, c_ast.ID) {
                names.add(nd.expr.name);
            }
        }
    }
    kids = nd?.children;
    if kids is not None {
        for (_, child) in kids() {
            _collect_int_use_names(child, names);
        }
    }
}

def _enumerator_value(en: object, counter: int) -> EnumVal {
    # Resolve one enumerator to its value and whether that value is a simple
    # constant. "Simple" means an implicit sequential value, a plain int
    # literal, or a negated int literal — the forms both enum walks below
    # understand. For anything else (arithmetic, identifiers, unparseable
    # suffixed literals) simple is False and value is a 0 placeholder. Single
    # source for both the strict ENUM_AS_ENUM check and the best-effort
    # ENUM_AS_CONSTS fallback.
    if not isinstance(en, c_ast.Enumerator) {
        return EnumVal(value=0, simple=False);
    }
    ev = getattr(en, "value");
    if ev is None {
        return EnumVal(value=counter, simple=True);
    }
    if isinstance(ev, c_ast.Constant) and ev.type == "int" {
        v = parse_c_int(ev.value);
        return EnumVal(value=v, simple=True)
            if v is not None
            else EnumVal(value=0, simple=False);
    }
    if (
        isinstance(ev, c_ast.UnaryOp)
        and ev.op == "-"
        and isinstance(ev.expr, c_ast.Constant)
        and ev.expr.type == "int"
    ) {
        v = parse_c_int(ev.expr.value);
        return EnumVal(value=-v, simple=True)
            if v is not None
            else EnumVal(value=0, simple=False);
    }
    return EnumVal(value=0, simple=False);
}

def _enum_sequential_values(enumerator_list: object) -> dict[str, int] | None {
    result: dict[str, int] = {};
    counter: int = 0;
    if not isinstance(enumerator_list, c_ast.EnumeratorList) {
        return None;
    }
    els = getattr(enumerator_list, "enumerators");
    if els is None {
        return None;
    }
    for en in els {
        if not isinstance(en, c_ast.Enumerator) {
            return None;
        }
        ev = _enumerator_value(en, counter);
        if not ev.simple {
            return None;
        }
        result[en.name] = ev.value;
        counter = ev.value + 1;
    }
    # Check no duplicate values.
    vals = list(result.values());
    if len(vals) != len(set(vals)) {
        return None;
    }
    # Check values are actually sequential (each = previous + 1).
    for i in range(1, len(vals)) {
        if vals[i] != vals[i - 1] + 1 {
            return None;
        }
    }
    return result;
}

def _collect_enums(nd: object, results: list[object]) {
    if isinstance(nd, c_ast.Enum) {
        results.append(nd);
    }
    kids = nd?.children;
    if kids is not None {
        for (_, child) in kids() {
            _collect_enums(child, results);
        }
    }
}

def build_enum_map(file_ast: object, tags: TagTable | None = None) -> EnumVerdicts {
    ev = EnumVerdicts();
    enums: list[object] = [];
    _collect_enums(file_ast, enums);
    # Pre-seed the collision set with every module-level identifier the lowered
    # output already binds, so the ENUM_AS_CONSTS collision check is complete and
    # order-independent rather than only catching enum-vs-enum clashes.
    seen_glob_names: set[str] = _collect_tu_names(file_ast);
    # Names consumed by integer arithmetic/bitwise ops anywhere in the TU; a named
    # enum whose members appear here is demoted from ENUM_AS_ENUM to ENUM_AS_CONSTS.
    int_use_names: set[str] = set();
    _collect_int_use_names(file_ast, int_use_names);
    for en in enums {
        if not isinstance(en, c_ast.Enum) {
            continue;
        }
        en_values = getattr(en, "values");
        if en_values is None {
            # Forward declaration — skip.
            continue;
        }
        name_map = _enum_sequential_values(en_values);
        en_name = getattr(en, "name");
        used_as_int = name_map is not None
        and any(nm in int_use_names for nm in name_map);
        if en_name is not None and name_map is not None and not used_as_int {
            # Candidate for ENUM_AS_ENUM.
            ev.verdicts[id(en)] = Idiom.ENUM_AS_ENUM;
            ev.name_map[id(en)] = name_map;
        } elif name_map is not None {
            # Anonymous, or a named enum whose members are used as integers
            # (demoted from ENUM_AS_ENUM above) — lower to consts, check collision.
            collision = False;
            for nm in name_map {
                if nm in seen_glob_names {
                    collision = True;
                    break;
                }
            }
            if collision {
                ev.verdicts[id(en)] = Idiom.TIER_B;
                ev.reasons[id(en)] = "enumerator name collides with an existing module global";
            } else {
                ev.verdicts[id(en)] = Idiom.ENUM_AS_CONSTS;
                for nm in name_map {
                    seen_glob_names.add(nm);
                }
                ev.name_map[id(en)] = name_map;
            }
        } else {
            # Complex values — ENUM_AS_CONSTS with best-effort or TIER_B.
            # Build a best-effort name→value map using the shared resolver; any
            # non-simple enumerator (expression / unparseable literal) places a 0
            # and forces TIER_B. The map is only consumed when ok stays True.
            best_map: dict[str, int] = {};
            counter = 0;
            ok = True;
            if isinstance(en_values, c_ast.EnumeratorList) {
                enrs = getattr(en_values, "enumerators");
                if enrs is not None {
                    for enr in enrs {
                        if not isinstance(enr, c_ast.Enumerator) {
                            ok = False;
                            continue;
                        }
                        enum_val = _enumerator_value(enr, counter);
                        best_map[enr.name] = enum_val.value;
                        counter = enum_val.value + 1;
                        if not enum_val.simple {
                            ok = False;
                        }
                    }
                }
            } else {
                ok = False;
            }
            # Evaluate collision manually to avoid Any-typed any() builtin.
            collision = False;
            for nm in best_map {
                if nm in seen_glob_names {
                    collision = True;
                    break;
                }
            }
            if not ok or collision {
                ev.verdicts[id(en)] = Idiom.TIER_B;
                ev.reasons[id(en)] = "enumerator name collides with an existing module global"
                    if collision
                    else "enum has non-constant enumerator values";
            } else {
                ev.verdicts[id(en)] = Idiom.ENUM_AS_CONSTS;
                for nm in best_map {
                    seen_glob_names.add(nm);
                }
                ev.name_map[id(en)] = best_map;
            }
        }
    }
    # Propagate verdicts into the tag table so the enum's idiom is recorded and
    # Tier-B enums (collisions / non-constant values) are flagged in the Tier-B comments.
    # Without this the default tagger leaves every Enum at TIER_A and a demoted
    # enum silently vanishes (uni_builder emits nothing) with an empty report.
    if tags is not None {
        for en in enums {
            if not isinstance(en, c_ast.Enum) {
                continue;
            }
            verdict = ev.verdicts.get(id(en));
            if verdict is None {
                continue;
            }
            coord = getattr(en, "coord");
            coord_line = getattr(coord, "line") if coord is not None else None;
            line: int = coord_line if isinstance(coord_line, int) else 0;
            if verdict == Idiom.TIER_B {
                reason = ev.reasons.get(
                    id(en), "enum not expressible as a Jac enum or consts"
                );
                tags.tag(
                    en,
                    NodeTag(
                        tier=Tier.TIER_B,
                        mechanism=Mechanism.DIRECT_IR,
                        idiom=Idiom.TIER_B,
                        reason=reason,
                        c_line=line,
                        snippet=reason
                    )
                );
            } else {
                tags.tag(
                    en,
                    NodeTag(
                        tier=Tier.TIER_A,
                        mechanism=Mechanism.DIRECT_IR,
                        idiom=verdict,
                        reason="",
                        c_line=line,
                        snippet=""
                    )
                );
            }
        }
    }
    return ev;
}
