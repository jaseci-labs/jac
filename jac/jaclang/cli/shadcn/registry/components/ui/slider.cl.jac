import from "radix-ui" { Slider as SliderPrimitive }
import from ...lib.utils { cn }

def:pub Slider(props: any) -> JsxElement {
    return
        <SliderPrimitive.Root
            {**props}
            data-slot="slider"
            className={cn(
                "cn-slider relative flex w-full touch-none items-center select-none data-disabled:opacity-50 data-vertical:h-full data-vertical:w-auto data-vertical:flex-col",
                props["className"]
            )}
        >
            <SliderPrimitive.Track
                data-slot="slider-track"
                className="cn-slider-track relative grow overflow-hidden data-horizontal:w-full data-vertical:h-full"
            >
                <SliderPrimitive.Range
                    data-slot="slider-range"
                    className="cn-slider-range absolute select-none data-horizontal:h-full data-vertical:w-full"
                />
            </SliderPrimitive.Track>
            <SliderPrimitive.Thumb
                data-slot="slider-thumb"
                className="cn-slider-thumb block shrink-0 select-none disabled:pointer-events-none disabled:opacity-50"
            />
        </SliderPrimitive.Root>;
}
