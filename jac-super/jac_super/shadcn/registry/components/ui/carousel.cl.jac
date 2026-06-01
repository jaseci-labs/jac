cl import from "embla-carousel-react" { default as useEmblaCarousel }
cl import from react { createContext, useContext }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowLeft01Icon, ArrowRight01Icon }
cl import from .button { Button }
cl import from ...lib.utils { cn }

glob CarouselContext: any = createContext(None);

cl {
    def:pub Carousel(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        orientation = props["orientation"] or "horizontal";
        axisOpt = "x" if orientation == "horizontal" else "y";
        embla: any = useEmblaCarousel({"axis": axisOpt}, props["plugins"]);
        carouselRef = embla[0];
        api: any = embla[1];
        scrollPrev = lambda -> any { api and api.scrollPrev(); };
        scrollNext = lambda -> any { api and api.scrollNext(); };
        ctxValue = {
            "carouselRef": carouselRef,
            "api": api,
            "orientation": orientation,
            "scrollPrev": scrollPrev,
            "scrollNext": scrollNext
        };
        return
            <CarouselContext.Provider value={ctxValue}>
                <div
                    {**attrs}
                    data-slot="carousel"
                    className={cn("relative", props["className"])}
                    role="region"
                    aria-roledescription="carousel"
                >
                    {props["children"]}
                </div>
            </CarouselContext.Provider>;
    }

    def:pub CarouselContent(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        ctx: any = useContext(CarouselContext);
        carouselRef = ctx.carouselRef if ctx else None;
        ori = ctx.orientation if ctx else "horizontal";
        dirClass = "-ml-4" if ori == "horizontal" else "-mt-4 flex-col";
        return
            <div
                ref={carouselRef}
                className="overflow-hidden"
                data-slot="carousel-content"
            >
                <div {**attrs} className={cn("flex", dirClass, props["className"])}/>
            </div>;
    }

    def:pub CarouselItem(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        ctx: any = useContext(CarouselContext);
        ori = ctx.orientation if ctx else "horizontal";
        padClass = "pl-4" if ori == "horizontal" else "pt-4";
        return
            <div
                {**attrs}
                role="group"
                aria-roledescription="slide"
                data-slot="carousel-item"
                className={cn(
                    "min-w-0 shrink-0 grow-0 basis-full", padClass, props["className"]
                )}
            />;
    }

    def:pub CarouselPrevious(props: any) -> JsxElement {
        ctx: any = useContext(CarouselContext);
        ori = ctx.orientation if ctx else "horizontal";
        scrollPrev = ctx.scrollPrev if ctx else None;
        posClass = "top-1/2 -left-12 -translate-y-1/2"
            if ori == "horizontal"
            else "-top-12 left-1/2 -translate-x-1/2 rotate-90";
        variant = props["variant"] or "outline";
        size = props["size"] or "icon-sm";
        return
            <Button
                {**props}
                data-slot="carousel-previous"
                variant={variant}
                size={size}
                className={cn(
                    "cn-carousel-previous absolute touch-manipulation",
                    posClass,
                    props["className"]
                )}
                onClick={scrollPrev}
            >
                <HugeiconsIcon
                    icon={ArrowLeft01Icon}
                    className="cn-rtl-flip"
                    size={16}
                />
                <span className="sr-only">Previous slide</span>
            </Button>;
    }

    def:pub CarouselNext(props: any) -> JsxElement {
        ctx: any = useContext(CarouselContext);
        ori = ctx.orientation if ctx else "horizontal";
        scrollNext = ctx.scrollNext if ctx else None;
        posClass = "top-1/2 -right-12 -translate-y-1/2"
            if ori == "horizontal"
            else "-bottom-12 left-1/2 -translate-x-1/2 rotate-90";
        variant = props["variant"] or "outline";
        size = props["size"] or "icon-sm";
        return
            <Button
                {**props}
                data-slot="carousel-next"
                variant={variant}
                size={size}
                className={cn(
                    "cn-carousel-next absolute touch-manipulation",
                    posClass,
                    props["className"]
                )}
                onClick={scrollNext}
            >
                <HugeiconsIcon
                    icon={ArrowRight01Icon}
                    className="cn-rtl-flip"
                    size={16}
                />
                <span className="sr-only">Next slide</span>
            </Button>;
    }
}
