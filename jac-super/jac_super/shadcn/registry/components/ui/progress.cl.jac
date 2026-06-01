cl import from "radix-ui" { Progress as ProgressPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Progress(props: any) -> JsxElement {
        value = props["value"] or 0;
        translateX = 100 - value;
        return
            <ProgressPrimitive.Root
                {**props}
                data-slot="progress"
                className={cn(
                    "cn-progress relative flex w-full items-center overflow-x-hidden",
                    props["className"]
                )}
            >
                <ProgressPrimitive.Indicator
                    data-slot="progress-indicator"
                    className="cn-progress-indicator size-full flex-1 transition-all"
                    style={{"transform": "translateX(-" + String(translateX) + "%)"}}
                />
            </ProgressPrimitive.Root>;
    }
}
