impl Badge(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    variant = kwargs.get("variant") or "default";
    asChild = kwargs.get("asChild") or False;

    variantsFn = _badgeVariants;
    computedClass = cn(variantsFn.call(None, {"variant": variant}), kwargs.get("className"));

    if asChild {
        return <Slot.Root
            {...kwargs}
            data-slot="badge"
            data-variant={variant}
            className={computedClass}
        />;
    }

    return <span {...attrs} data-slot="badge" data-variant={variant} className={computedClass} />;
}

impl badgeVariants -> any {
    return _badgeVariants;
}
