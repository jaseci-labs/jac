import jaclang.compiler.passes.ecmascript.estree as es;
import jaclang.jac0core.unitree as uni;

obj HostTag {
    has name: str,
        jac_node: (uni.UniNode | None);
}

obj ComponentTag {
    has ref: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj FragmentTag {
    has jac_node: uni.UniNode;
}

obj DynamicTag {
    has expr: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj StaticAttr {
    has name: str,
        value: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj DynamicAttr {
    has name: str,
        value: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj EventAttr {
    has name: str,
        handler: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj RefAttr {
    has name: str,
        value: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj SpreadAttr {
    has value: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj TextChild {
    has value: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj DynamicChild {
    has value: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj ElementChild {
    has element: ViewElement,
        jac_node: (uni.UniNode | None);
}

obj SlotChild {
    has expr: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj IfChild {
    has test: es.Expression,
        consequent:
            list[
                TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
            ],
        alternate:
            (
                list[
                    TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
                ] | None
            ),
        js_fallback: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj EachChild {
    has items: es.Expression,
        item: str,
        key: (es.Expression | None),
        body:
            list[
                TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
            ],
        js_fallback: es.Expression,
        jac_node: (uni.UniNode | None);
}

obj ViewElement {
    has tag: (HostTag | ComponentTag | FragmentTag | DynamicTag),
        attrs: list[StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr],
        children:
            list[
                TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
            ],
        jac_node: (uni.UniNode | None);
}
