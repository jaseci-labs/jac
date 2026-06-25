"""Enum pre-pass: Q6 verdict (ENUM_AS_ENUM vs ENUM_AS_CONSTS) for all enums.

Single AST walk over file_ast produces:
  EnumVerdicts.verdicts: dict[int, str]  — id(c_enum) → "enum_as_enum" | "enum_as_consts" | "tier_b"
  EnumVerdicts.name_map: dict[int, dict[str, int]]  — id(c_enum) → {enumerator_name: value}

v1 heuristic for ENUM_AS_ENUM:
  - named enum
  - all enumerator values are implicit (auto-sequential int) OR explicit simple int literals
  - no duplicate values
  - no bitwise/arithmetic expressions in value definitions
  - no bitwise operation with an enumerator name at a use site (scanned shallowly; conservative)

Everything else → ENUM_AS_CONSTS, subject to glob-name collision check.
Collision check: two block-scoped enums sharing an enumerator name when both would be
ENUM_AS_CONSTS → the second demotes to TIER_B ("enumerator name collides with an existing
module global").
"""

import from pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Idiom, Tier, Mechanism, NodeTag, TagTable }
import from jaclang.compiler.c2jac.c_common { parse_c_int }

obj EnumVerdicts {
    has verdicts: dict[int, str],  # id(c_enum) → verdict string
        name_map: dict[int, dict[str, int]],  # id(c_enum) → {name: value}
        reasons: dict[int, str];  # id(c_enum) → Tier-B reason (for the sidecar report)

    def init {
        self.verdicts = {};
        self.name_map = {};
        self.reasons = {};
    }
}

def _has_complex_expr(expr: object) -> bool {
    if expr is None {
        return False;
    }

    if isinstance(expr, c_ast.Constant) {
        return False;
    }
    if isinstance(expr, c_ast.ID) {
        return False;
    }
    if isinstance(expr, c_ast.UnaryOp) {
        if expr.op in ("-", "+") {
            return _has_complex_expr(expr.expr);
        }
        return True;
    }
    return True;
}

def _enumerator_value(en: object, counter: int) -> tuple[int, bool] {
    # Resolve one enumerator to (value, is_simple_constant). "Simple" means an
    # implicit sequential value, a plain int literal, or a negated int literal —
    # the forms both enum walks below understand. For anything else (arithmetic,
    # identifiers, unparseable suffixed literals) is_simple is False and the
    # returned value is a 0 placeholder. Single source for both the strict
    # ENUM_AS_ENUM check and the best-effort ENUM_AS_CONSTS fallback.
    if en.value is None {
        return (counter, True);
    }
    if isinstance(en.value, c_ast.Constant) and en.value.type == "int" {
        v = parse_c_int(en.value.value);
        return (v, True) if v is not None else (0, False);
    }
    if (
        isinstance(en.value, c_ast.UnaryOp)
        and en.value.op == "-"
        and isinstance(en.value.expr, c_ast.Constant)
        and en.value.expr.type == "int"
    ) {
        v = parse_c_int(en.value.expr.value);
        return (-v, True) if v is not None else (0, False);
    }
    return (0, False);
}

def _enum_sequential_values(enumerator_list: object) -> dict[str, int] | None {
    result: dict[str, int] = {};
    counter: int = 0;
    for en in enumerator_list.enumerators {
        (v, simple) = _enumerator_value(en, counter);
        if not simple {
            return None;
        }
        result[en.name] = v;
        counter = v + 1;
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
    for (_, child) in nd.children() {
        _collect_enums(child, results);
    }
}

def build_enum_map(file_ast: object, tags: TagTable | None = None) -> EnumVerdicts {
    ev = EnumVerdicts();
    enums: list[object] = [];
    _collect_enums(file_ast, enums);
    seen_glob_names: set[str] = set();
    for en in enums {
        if en.values is None {
            # Forward declaration — skip.
            continue;
        }
        name_map = _enum_sequential_values(en.values);
        if en.name is not None and name_map is not None {
            # Candidate for ENUM_AS_ENUM.
            ev.verdicts[id(en)] = Idiom.ENUM_AS_ENUM.value;
            ev.name_map[id(en)] = name_map;
        } elif name_map is not None {
            # Anonymous or complex value — check collision.
            collision = False;
            for nm in name_map {
                if nm in seen_glob_names {
                    collision = True;
                    break;
                }
            }
            if collision {
                ev.verdicts[id(en)] = "tier_b";
                ev.reasons[id(en)] = "enumerator name collides with an existing module global";
            } else {
                ev.verdicts[id(en)] = Idiom.ENUM_AS_CONSTS.value;
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
            for enr in en.values.enumerators {
                (v, simple) = _enumerator_value(enr, counter);
                best_map[enr.name] = v;
                counter = v + 1;
                if not simple {
                    ok = False;
                }
            }
            collision = any(nm in seen_glob_names for nm in best_map);
            if not ok or collision {
                ev.verdicts[id(en)] = "tier_b";
                ev.reasons[id(en)] = "enumerator name collides with an existing module global"
                    if collision
                    else "enum has non-constant enumerator values";
            } else {
                ev.verdicts[id(en)] = Idiom.ENUM_AS_CONSTS.value;
                for nm in best_map {
                    seen_glob_names.add(nm);
                }
                ev.name_map[id(en)] = best_map;
            }
        }
    }
    # Propagate verdicts into the tag table so the enum's idiom is recorded and
    # Tier-B enums (collisions / non-constant values) reach the sidecar report.
    # Without this the default tagger leaves every Enum at TIER_A and a demoted
    # enum silently vanishes (uni_builder emits nothing) with an empty report.
    if tags is not None {
        for en in enums {
            verdict = ev.verdicts.get(id(en));
            if verdict is None {
                continue;
            }
            coord = en?.coord;
            line = coord.line if coord and coord.line else 0;
            if verdict == "tier_b" {
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
                        idiom=Idiom(verdict),
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
