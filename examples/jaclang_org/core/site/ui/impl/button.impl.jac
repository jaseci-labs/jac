impl Button(**kwargs: any) -> JsxElement {
    variant = kwargs.get("variant") or "default";
    size = kwargs.get("size") or "default";
    asChild = kwargs.get("asChild") or False;

    restProps: dict[str, any] = {};
    for key in kwargs.keys() {
        if key not in _buttonExcludeKeys {
            restProps[key] = kwargs[key];
        }
    }

    computedClass = cn(
        _buttonVariants.call(
            None, {"variant": variant, "size": size, "className": kwargs.get("className")}
        ),
    );

    if asChild {
        return <Slot.Root
            data-slot="button"
            data-variant={variant}
            data-size={size}
            className={computedClass}
            {...restProps}
        >{kwargs.get("children")}</Slot.Root>;
    }

    return <button
        data-slot="button"
        data-variant={variant}
        data-size={size}
        className={computedClass}
        {...restProps}
    >{kwargs.get("children")}</button>;
}

impl buttonVariants -> any {
    return _buttonVariants;
}
