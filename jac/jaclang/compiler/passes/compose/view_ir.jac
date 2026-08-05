import jaclang.jac0core.unitree as uni;
import type from jaclang.compiler.passes.compose.kotlin_ast { KtNode }
import from jaclang.compiler.type_system.compose_signatures { ComposeParamKind }

obj ComposeAttr {
    has name: str,
        value: KtNode,
        param_kind: (ComposeParamKind | None) = None,
        is_event: bool = False,
        jac_node: (uni.UniNode | None) = None;
}

obj ComposeTextChild {
    has value: KtNode,
        jac_node: (uni.UniNode | None) = None;
}

obj ComposeDynamicChild {
    has value: KtNode,
        jac_node: (uni.UniNode | None) = None;
}

obj ComposeRawChild {
    has code: str,
        jac_node: (uni.UniNode | None) = None;
}

obj ComposeElementChild {
    has element: ComposeElement,
        jac_node: (uni.UniNode | None) = None;
}

obj ComposeIfChild {
    has `test: KtNode,
        consequent:
            list[
                ComposeTextChild
                    | ComposeDynamicChild
                    | ComposeRawChild
                    | ComposeElementChild
                    | ComposeIfChild
                    | ComposeEachChild
            ],
        alternate:
            (
                list[
                    ComposeTextChild
                        | ComposeDynamicChild
                        | ComposeRawChild
                        | ComposeElementChild
                        | ComposeIfChild
                        | ComposeEachChild
                ]
                | None
            ) = None,
        jac_node: (uni.UniNode | None) = None;
}

obj ComposeEachChild {
    has items: KtNode,
        item_name: str,
        body:
            list[
                ComposeTextChild
                    | ComposeDynamicChild
                    | ComposeRawChild
                    | ComposeElementChild
                    | ComposeIfChild
                    | ComposeEachChild
            ],
        jac_node: (uni.UniNode | None) = None;
}

obj ComposeElement {
    has name: str,
        attrs: list[ComposeAttr] = [],
        children:
            list[
                ComposeTextChild
                    | ComposeDynamicChild
                    | ComposeRawChild
                    | ComposeElementChild
                    | ComposeIfChild
                    | ComposeEachChild
            ] = [],
        jac_node: (uni.UniNode | None) = None;
}
