impl Button(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    size = props["size"] or "default";
    asChild = props["asChild"] or False;

    restProps = {};
    for key in Object.keys(props) {
        if key not in _buttonExcludeKeys {
            restProps[key] = props[key];
        }
    }

    computedClass = cn(
        _buttonVariants.call(
            None, {"variant": variant, "size": size, "className": props["className"]}
        )
    );

    if asChild {
        return
            <Slot.Root
                data-slot="button"
                data-variant={variant}
                data-size={size}
                className={computedClass}
                {**restProps}
            >
                {props["children"]}
            </Slot.Root>;
    }

    return
        <button
            data-slot="button"
            data-variant={variant}
            data-size={size}
            className={computedClass}
            {**restProps}
        >
            {props["children"]}
        </button>;
}
