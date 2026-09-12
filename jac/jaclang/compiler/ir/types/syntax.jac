import type from collections.abc { Sequence }
import type from jaclang.compiler.ir.types.nodes { TypeBase }
import type from jaclang.compiler.ir.values { CtValue }

import from jaclang.compiler.ir.base { UniNode }
import type from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
import type from jaclang.compiler.ir.syntax.nodes { Token, SubTag }
import from jaclang.compiler.ir.base { TypedNode }

node AstTypedVarNode(TypedNode) {
    has type: (TypeBase | None) { getter; setter(type: (TypeBase | None)); }
    has type_tag: (SubTag[Expr] | None) { getter; }

    def init(
        *,
        type_tag: (SubTag[Expr] | None) = None,
        type: (TypeBase | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node Expr(TypedNode) {
    has type: (TypeBase | None) { getter; setter(type: (TypeBase | None)); }
    has narrowed_type: (TypeBase | None) {
        getter;
        setter(narrowed_type: (TypeBase | None));
    }

    has _type_sym_tab: (UniScopeNode | None) postinit,
        _type_cache: (TypeBase | None) postinit,
        _type_generation: int = -1,
        _type_cache_ok: bool postinit,
        ct_value: CtValue | None postinit,
        coerce_to: (str | None) postinit,
        fw: (str | None) postinit,
        fw_safe: bool postinit,
        attached_tokens: (list[Token] | None) postinit;

    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;

    has type_sym_tab: (UniScopeNode | None) {
        getter;
        setter(type_sym_tab: UniScopeNode);
    }

    def __repr__ -> str;
}
