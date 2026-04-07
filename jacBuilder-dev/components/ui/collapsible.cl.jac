cl import from "radix-ui" { Collapsible as CollapsiblePrimitive }

cl {
    def:pub Collapsible(props: Any) -> JsxElement {
        return <CollapsiblePrimitive.Root data-slot="collapsible" {...props} />;
    }

    def:pub CollapsibleTrigger(props: Any) -> JsxElement {
        return <CollapsiblePrimitive.CollapsibleTrigger data-slot="collapsible-trigger" {...props} />;
    }

    def:pub CollapsibleContent(props: Any) -> JsxElement {
        return <CollapsiblePrimitive.CollapsibleContent data-slot="collapsible-content" {...props} />;
    }
}
