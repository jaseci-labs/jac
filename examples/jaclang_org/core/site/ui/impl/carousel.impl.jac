impl Carousel(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    orientation = kwargs.get("orientation") or "horizontal";
    axisOpt = "x" if orientation == "horizontal" else "y";
    userOpts: dict[str, any] = (kwargs.get("opts") or {}) as dict[str, any];
    embla: any = useEmblaCarousel({"axis": axisOpt, **userOpts}, kwargs.get("plugins"));
    carouselRef = embla[0];
    api: any = embla[1];
    scrollPrev = lambda -> any { api and api.scrollPrev() };
    scrollNext = lambda -> any { api and api.scrollNext() };
    ctxValue = {
        "carouselRef": carouselRef,
        "api": api,
        "orientation": orientation,
        "scrollPrev": scrollPrev,
        "scrollNext": scrollNext,
    };
    return <CarouselContext.Provider value={ctxValue}>
        <div
            {...attrs}
            data-slot="carousel"
            className={cn("relative", kwargs.get("className"))}
            role="region"
            aria-roledescription="carousel"
        >{kwargs.get("children")}</div>
    </CarouselContext.Provider>;
}

impl CarouselContent(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    ctx: any = useContext(CarouselContext);
    carouselRef = ctx.carouselRef if ctx else None;
    ori = ctx.orientation if ctx else "horizontal";
    dirClass = "-ml-4" if ori == "horizontal" else "-mt-4 flex-col";
    return <div ref={carouselRef} className="overflow-hidden" data-slot="carousel-content">
        <div {...attrs} className={cn("flex", dirClass, kwargs.get("className"))} />
    </div>;
}

impl CarouselItem(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    ctx: any = useContext(CarouselContext);
    ori = ctx.orientation if ctx else "horizontal";
    padClass = "pl-4" if ori == "horizontal" else "pt-4";
    return <div
        {...attrs}
        role="group"
        aria-roledescription="slide"
        data-slot="carousel-item"
        className={cn("min-w-0 shrink-0 grow-0 basis-full", padClass, kwargs.get("className"))}
    />;
}

impl CarouselDot(index: int, selected: int) -> JsxElement {
    ctx: any = useContext(CarouselContext);

    def go(_e: any) {
        if ctx and ctx.api {
            ctx.api.scrollTo(index);
        }
    }

    return <button
        type="button"
        onClick={go}
        aria-label={"Go to slide " + str(index + 1)}
        className={cn("h-2 cursor-pointer rounded-full transition-all duration-300", "w-5 bg-primary" if selected == index else "w-2 bg-muted-foreground/30 hover:bg-muted-foreground/60")}
    />;
}

impl CarouselDots(**kwargs: any) -> JsxElement {
    has selected: int = 0,
        count: int = 0;

    ctx: any = useContext(CarouselContext);
    api: any = ctx.api if ctx else None;

    useEffect(
        lambda {
            if not api {
                return lambda {};
            }
            update = lambda (_a: any) {
                count = len(api.scrollSnapList());
                selected = api.selectedScrollSnap();
            };
            update(None);
            api.on("select", update);
            api.on("reInit", update);
            return lambda {
                api.off("select", update);
                api.off("reInit", update);
            };
        },
        [api],
    );

    return <div
        data-slot="carousel-dots"
        className={cn("flex items-center justify-center gap-2", kwargs.get("className"))}
    >
        {
            for i in range(count) {
                <CarouselDot key={str(i)} index={i} selected={selected} />
            }
        }
    </div>;
}

impl CarouselPrevious(**kwargs: any) -> JsxElement {
    ctx: any = useContext(CarouselContext);
    ori = ctx.orientation if ctx else "horizontal";
    scrollPrev = ctx.scrollPrev if ctx else None;
    posClass = "top-1/2 -left-12 -translate-y-1/2"
        if ori == "horizontal"
        else "-top-12 left-1/2 -translate-x-1/2 rotate-90";
    variant = kwargs.get("variant") or "outline";
    size = kwargs.get("size") or "icon-sm";
    return <Button
        {...kwargs}
        data-slot="carousel-previous"
        variant={variant}
        size={size}
        className={cn("rounded-full absolute touch-manipulation", posClass, kwargs.get("className"))}
        onClick={scrollPrev}
    >
        <HugeiconsIcon icon={ArrowLeft01Icon} className="cn-rtl-flip" size={16} />
        <span className="sr-only">Previous slide</span>
    </Button>;
}

impl CarouselNext(**kwargs: any) -> JsxElement {
    ctx: any = useContext(CarouselContext);
    ori = ctx.orientation if ctx else "horizontal";
    scrollNext = ctx.scrollNext if ctx else None;
    posClass = "top-1/2 -right-12 -translate-y-1/2"
        if ori == "horizontal"
        else "-bottom-12 left-1/2 -translate-x-1/2 rotate-90";
    variant = kwargs.get("variant") or "outline";
    size = kwargs.get("size") or "icon-sm";
    return <Button
        {...kwargs}
        data-slot="carousel-next"
        variant={variant}
        size={size}
        className={cn("rounded-full absolute touch-manipulation", posClass, kwargs.get("className"))}
        onClick={scrollNext}
    >
        <HugeiconsIcon icon={ArrowRight01Icon} className="cn-rtl-flip" size={16} />
        <span className="sr-only">Next slide</span>
    </Button>;
}
