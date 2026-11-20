impl FieldSet(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <fieldset
        {...attrs}
        data-slot="field-set"
        className={cn("gap-4 has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3 gap-4 has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3 flex flex-col", kwargs.get("className"))}
    />;
}

impl FieldLegend(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    variant = kwargs.get("variant") or "legend";
    return <legend
        {...attrs}
        data-slot="field-legend"
        data-variant={variant}
        className={cn("mb-1.5 font-medium data-[variant=label]:text-sm data-[variant=legend]:text-base mb-1.5 font-medium data-[variant=label]:text-sm data-[variant=legend]:text-base", kwargs.get("className"))}
    />;
}

impl FieldGroup(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="field-group"
        className={cn("gap-5 data-[slot=checkbox-group]:gap-3 *:data-[slot=field-group]:gap-4 gap-5 data-[slot=checkbox-group]:gap-3 *:data-[slot=field-group]:gap-4 group/field-group @container/field-group flex w-full flex-col", kwargs.get("className"))}
    />;
}

impl Field(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    orientation = kwargs.get("orientation") or "vertical";
    variantsFn = _fieldVariants;
    return <div
        {...attrs}
        role="group"
        data-slot="field"
        data-orientation={orientation}
        className={cn(variantsFn.call(None, {"orientation": orientation}), kwargs.get("className"))}
    />;
}

impl FieldContent(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="field-content"
        className={cn("gap-0.5 gap-0.5 group/field-content flex flex-1 flex-col leading-snug", kwargs.get("className"))}
    />;
}

impl FieldLabel(**kwargs: any) -> JsxElement {
    return <Label
        {...kwargs}
        data-slot="field-label"
        className={cn("has-data-checked:bg-primary/5 has-data-checked:border-primary/30 dark:has-data-checked:border-primary/20 dark:has-data-checked:bg-primary/10 gap-2 group-data-[disabled=true]/field:opacity-50 has-[>[data-slot=field]]:rounded-lg has-[>[data-slot=field]]:border *:data-[slot=field]:p-2.5 has-data-checked:bg-primary/5 has-data-checked:border-primary/30 dark:has-data-checked:border-primary/20 dark:has-data-checked:bg-primary/10 gap-2 group-data-[disabled=true]/field:opacity-50 has-[>[data-slot=field]]:rounded-lg has-[>[data-slot=field]]:border *:data-[slot=field]:p-2.5 group/field-label peer/field-label flex w-fit leading-snug", "has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col", kwargs.get("className"))}
    />;
}

impl FieldTitle(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="field-label"
        className={cn("gap-2 text-sm font-medium group-data-[disabled=true]/field:opacity-50 gap-2 text-sm font-medium group-data-[disabled=true]/field:opacity-50 flex w-fit items-center leading-snug", kwargs.get("className"))}
    />;
}

impl FieldDescription(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <p
        {...attrs}
        data-slot="field-description"
        className={cn("text-muted-foreground text-left text-sm [[data-variant=legend]+&]:-mt-1.5 text-muted-foreground text-left text-sm [[data-variant=legend]+&]:-mt-1.5 leading-normal font-normal group-has-data-horizontal/field:text-balance", "last:mt-0 nth-last-2:-mt-1", "[&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4", kwargs.get("className"))}
    />;
}

impl FieldSeparator(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="field-separator"
        data-content={Boolean(kwargs.get("children"))}
        className={cn("-my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2 -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2 relative", kwargs.get("className"))}
    >
        <Separator className="absolute inset-0 top-1/2" />
        {kwargs.get("children")
            and (<span
                className="text-muted-foreground px-2 bg-background relative mx-auto block w-fit"
                data-slot="field-separator-content"
            >{kwargs.get("children")}</span>)}
    </div>;
}

impl FieldError(**kwargs: any) -> any {
    attrs: dict[str, any] = {**kwargs};
    children = kwargs.get("children");
    errors = kwargs.get("errors");

    content = useMemo(
        lambda -> any {
            if children {
                return children;
            }
            errorList: list[any] = [e for e in (errors or [])];
            if not len(errorList) {
                return None;
            }
            uniqueMap: dict[str, any] = {};
            for error in errorList {
                uniqueMap[error and error.message] = error;
            }
            uniqueKeys = Object.keys(uniqueMap);  # jac:ignore[W6001]
            uniqueErrors: list[any] = [uniqueMap[k] for k in uniqueKeys];
            if len(uniqueErrors) == 1 {
                return uniqueErrors[0] and uniqueErrors[0].message;
            }
            return <ul className="ml-4 flex list-disc flex-col gap-1">
                {
                    for (index, error) in enumerate(uniqueErrors) {
                        if error and error.message {
                            <li key={index}>{error.message}</li>;
                        }
                    }
                }
            </ul>;
        },
        [children, errors],
    );

    if not content {
        return None;
    }

    return <div
        {...attrs}
        role="alert"
        data-slot="field-error"
        className={cn("text-destructive text-sm text-destructive text-sm font-normal", kwargs.get("className"))}
    >{content}</div>;
}
