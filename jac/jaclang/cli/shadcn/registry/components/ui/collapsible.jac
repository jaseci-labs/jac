import from "radix-ui" { Collapsible as CollapsiblePrimitive }

def:pub Collapsible(props: any) -> JsxElement {
    <CollapsiblePrimitive.Root data-slot="collapsible" {**props}/>
}

def:pub CollapsibleTrigger(props: any) -> JsxElement {
    <CollapsiblePrimitive.CollapsibleTrigger data-slot="collapsible-trigger" {**props}/>
}

def:pub CollapsibleContent(props: any) -> JsxElement {
    <CollapsiblePrimitive.CollapsibleContent data-slot="collapsible-content" {**props}/>
}
