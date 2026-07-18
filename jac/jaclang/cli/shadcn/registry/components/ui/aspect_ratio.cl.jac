import from "radix-ui" { AspectRatio as AspectRatioPrimitive }

def:pub AspectRatio(props: any) -> JsxElement {
    return <AspectRatioPrimitive.Root data-slot="aspect-ratio" {**props}/>;
}
