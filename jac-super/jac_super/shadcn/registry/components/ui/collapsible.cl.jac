cl import from "radix-ui" { Collapsible as CollapsiblePrimitive }

cl {
    def:pub Collapsible(props: any) -> JsxElement {
        return <CollapsiblePrimitive.Root data-slot="collapsible" {**props}/>;
    }

    def:pub CollapsibleTrigger(props: any) -> JsxElement {
        return
            <CollapsiblePrimitive.CollapsibleTrigger
                data-slot="collapsible-trigger"
                {**props}
            />;
    }

    def:pub CollapsibleContent(props: any) -> JsxElement {
        return
            <CollapsiblePrimitive.CollapsibleContent
                data-slot="collapsible-content"
                {**props}
            />;
    }
}
