import from "radix-ui" { Label as LabelPrimitive }
import from ....core.utils { cn }

def:pub Label(props: any) -> JsxElement {
    <LabelPrimitive.Root
        {**props}
        data-slot="label"
        className={cn(
            "flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50",
            props["className"]
        )}
    />
}
