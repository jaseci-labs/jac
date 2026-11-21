impl Separator(**kwargs: any) -> JsxElement {
    orientation = kwargs.get("orientation") or "horizontal";
    decorative = kwargs.get("decorative");
    if decorative is None {
        decorative = True;
    }
    return <SeparatorPrimitive.Root
        {...kwargs}
        data-slot="separator"
        decorative={decorative}
        orientation={orientation}
        className={cn("bg-border shrink-0 data-horizontal:h-px data-horizontal:w-full data-vertical:w-px data-vertical:self-stretch", kwargs.get("className"))}
    />;
}
