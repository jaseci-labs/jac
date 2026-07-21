import from "radix-ui" { Label as LabelPrimitive }
import from ...lib.utils { cn }

def:pub Label(props: any) -> JsxElement {
    return
        <LabelPrimitive.Root
            {**props}
            data-slot="label"
            className={cn(
                "gap-2 text-sm leading-none font-medium group-data-[disabled=true]:opacity-50 peer-disabled:opacity-50 gap-2 text-sm leading-none font-medium group-data-[disabled=true]:opacity-50 peer-disabled:opacity-50 flex items-center select-none group-data-[disabled=true]:pointer-events-none peer-disabled:cursor-not-allowed",
                props["className"]
            )}
        />;
}
