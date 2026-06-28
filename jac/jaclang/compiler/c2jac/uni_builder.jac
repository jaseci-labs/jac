"""Direct-IR path: pycparser C-AST → uni nodes for constructs with no Python-AST analog.

Covers the enum forms (→ uni.Enum or glob GlobalVars). Used by the driver's
splice step after PyastBuildPass has built the base uni tree.

C-for loops are NOT built here: they are desugared to ordinary CPython `ast`
(`init; while cond { body; step }`) by the mapper's single-sourced c_For, and a
*promotable* one is rewritten from the spliced WhileStmt into a native
IterForStmt by the driver (driver._promote_for). This keeps loop-body lowering in
one place — the mapper — instead of mirroring every statement form here.
"""

import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.c2jac.tags { Idiom, TagTable }
import from jaclang.compiler.c2jac.enum_prepass { EnumVerdicts }
import from jaclang.compiler.c2jac.c_common { coord_of }

obj CUniBuilder {
    has src: uni.Source,
        tags: TagTable,
        enum_verdicts: EnumVerdicts;

    def init(src: uni.Source, tags: TagTable, enum_verdicts: EnumVerdicts) {
        self.src = src;
        self.tags = tags;
        self.enum_verdicts = enum_verdicts;
    }

    # ------------------------------------------------------------------ #
    # Node factories                                                        #
    # ------------------------------------------------------------------ #
    def _name_node(value: str, line: int, col: int) -> uni.Name {
        return uni.Name(
            orig_src=self.src,
            name="NAME",
            value=value,
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + len(value),
            pos_start=0,
            pos_end=len(value),
        );
    }

    def _int_node(value: int, line: int, col: int) -> uni.Int {
        sv = str(value);
        return uni.Int(
            orig_src=self.src,
            name="INT",
            value=sv,
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + len(sv),
            pos_start=0,
            pos_end=len(sv),
        );
    }

    def _coord(c_node: object) -> tuple[int, int] {
        # Direct-IR builder has no running line cursor; fall back to line 1.
        return coord_of(c_node, 1);
    }

    # ------------------------------------------------------------------ #
    # Main dispatch                                                         #
    # ------------------------------------------------------------------ #
    def build(c_node: object) -> list[uni.UniNode] {
        tp = type(c_node).__name__;
        if tp == "Enum" {
            return self._build_enum(c_node);
        }
        # Fallthrough — shouldn't happen; return empty.
        return [];
    }

    # ------------------------------------------------------------------ #
    # Enum → uni.Enum or GlobalVars                                         #
    # ------------------------------------------------------------------ #
    def _build_enum(nd: object) -> list[uni.UniNode] {
        verdict = self.enum_verdicts.verdicts.get(id(nd), Idiom.TIER_B);
        name_map = self.enum_verdicts.name_map.get(id(nd), {});
        (line, col) = self._coord(nd);
        if verdict == Idiom.ENUM_AS_ENUM {
            return [self._enum_as_enum(nd, name_map, line, col)];
        }
        if verdict == Idiom.ENUM_AS_CONSTS {
            return self._enum_as_consts(name_map, line, col);
        }
        # TIER_B — emit nothing here; the mapper's placeholder already carries the surrogate.
        return [];
    }

    def _enum_as_enum(
        nd: object, name_map: dict[str, int], line: int, col: int
    ) -> uni.Enum {
        enum_name_str = nd.name or "_AnonEnum";
        enum_name = self._name_node(enum_name_str, line, col);
        members: list[uni.UniNode] = [];
        for (nm, val) in name_map.items() {
            m_name = self._name_node(nm, line, col);
            m_val = self._int_node(val, line, col);
            assign = uni.Assignment(
                kid=[m_name, m_val],
                target=[m_name],
                value=m_val,
                type_tag=None,
                mutable=False,
                aug_op=None,
                is_enum_stmt=True,
            );
            members.append(assign);
        }
        # Enum.body must be a list of EnumBlockStmt (Assignment) items, not a
        # wrapped EnumBlockStmt node — NormalizePass.enter_enum iterates nd.body.
        return uni.Enum(
            kid=[enum_name, *members],
            doc=None,
            is_async=False,
            body=members,
            access=None,
            decorators=None,
            name=enum_name,
            value_type=None,
            base_classes=None,
        );
    }

    def _enum_as_consts(
        name_map: dict[str, int], line: int, col: int
    ) -> list[uni.GlobalVars] {
        results: list[uni.GlobalVars] = [];
        for (nm, val) in name_map.items() {
            name_n = self._name_node(nm, line, col);
            val_n = self._int_node(val, line, col);
            assign = uni.Assignment(
                kid=[name_n, val_n],
                target=[name_n],
                value=val_n,
                type_tag=None,
                mutable=False,
                aug_op=None,
                is_enum_stmt=False,
            );
            gv = uni.GlobalVars(
                kid=[assign],
                access=None,
                doc=None,
                assignments=[assign],
                is_frozen=True,
            );
            results.append(gv);
        }
        return results;
    }
}
