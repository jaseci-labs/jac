impl Badge(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    variant = props["variant"] or "default";
    asChild = props["asChild"] or False;

    variantsFn = _badgeVariants;
    computedClass = cn(variantsFn.call(None, {"variant": variant}), props["className"]);

    if asChild {
        return
            <Slot.Root
                {**props}
                data-slot="badge"
                data-variant={variant}
                className={computedClass}
            />;
    }

    return
        <span
            {**attrs}
            data-slot="badge"
            data-variant={variant}
            className={computedClass}
        />;
}
