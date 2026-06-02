cl import from "radix-ui" { Label as LabelPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Label(props: any) -> JsxElement {
        return
            <LabelPrimitive.Root
                {**props}
                data-slot="label"
                className={cn(
                    "cn-label gap-2 text-sm leading-none font-medium group-data-[disabled=true]:opacity-50 peer-disabled:opacity-50 flex items-center select-none group-data-[disabled=true]:pointer-events-none peer-disabled:cursor-not-allowed",
                    props["className"]
                )}
            />;
    }
}
