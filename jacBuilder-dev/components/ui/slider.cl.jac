cl import from "radix-ui" { Slider as SliderPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Slider(props: Any) -> JsxElement {
        return <SliderPrimitive.Root
            {...props}
            data-slot="slider"
            className={cn("data-vertical:min-h-40 relative flex w-full touch-none items-center select-none data-disabled:opacity-50 data-vertical:h-full data-vertical:w-auto data-vertical:flex-col", props.className)}
        >
            <SliderPrimitive.Track
                data-slot="slider-track"
                className="bg-muted rounded-full data-horizontal:h-1 data-horizontal:w-full data-vertical:h-full data-vertical:w-1 relative grow overflow-hidden data-horizontal:w-full data-vertical:h-full"
            >
                <SliderPrimitive.Range
                    data-slot="slider-range"
                    className="bg-primary absolute select-none data-horizontal:h-full data-vertical:w-full"
                />
            </SliderPrimitive.Track>
            <SliderPrimitive.Thumb
                data-slot="slider-thumb"
                className="border-ring ring-ring/50 relative size-3 rounded-full border bg-white transition-[color,box-shadow] after:absolute after:-inset-2 hover:ring-3 focus-visible:ring-3 focus-visible:outline-hidden active:ring-3 block shrink-0 select-none disabled:pointer-events-none disabled:opacity-50"
            />
        </SliderPrimitive.Root>;
    }
}
