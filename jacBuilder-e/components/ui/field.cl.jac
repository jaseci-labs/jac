cl import from react { useMemo }
cl import from "class-variance-authority" { cva }
cl import from ...lib.utils { cn }
cl import from .label { Label }
cl import from .separator { Separator }

glob _fieldVariants: Any = cva(
    "data-[invalid=true]:text-destructive gap-2 data-[invalid=true]:text-destructive gap-2 group/field flex w-full",
    {
        "variants": {
            "orientation": {
                "vertical": "data-[invalid=true]:text-destructive gap-2-orientation-vertical flex-col *:w-full [&>.sr-only]:w-auto",
                "horizontal": "data-[invalid=true]:text-destructive gap-2-orientation-horizontal flex-row items-center *:data-[slot=field-label]:flex-auto has-[>[data-slot=field-content]]:items-start has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px",
                "responsive": "data-[invalid=true]:text-destructive gap-2-orientation-responsive flex-col *:w-full [&>.sr-only]:w-auto @md/field-group:flex-row @md/field-group:items-center @md/field-group:*:w-auto @md/field-group:*:data-[slot=field-label]:flex-auto @md/field-group:has-[>[data-slot=field-content]]:items-start @md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
            }
        },
        "defaultVariants": {
            "orientation": "vertical"
        }
    }
);

cl {
    def:pub FieldSet(props: Any) -> JsxElement {
        return <fieldset
            {...props}
            data-slot="field-set"
            className={cn("gap-4 has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3 gap-4 has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3 flex flex-col", props.className)}
        />;
    }

    def:pub FieldLegend(props: Any) -> JsxElement {
        variant = props.variant or "legend";
        return <legend
            {...props}
            data-slot="field-legend"
            data-variant={variant}
            className={cn("mb-1.5 font-medium data-[variant=label]:text-sm data-[variant=legend]:text-base mb-1.5 font-medium data-[variant=label]:text-sm data-[variant=legend]:text-base", props.className)}
        />;
    }

    def:pub FieldGroup(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="field-group"
            className={cn("gap-5 data-[slot=checkbox-group]:gap-3 *:data-[slot=field-group]:gap-4 gap-5 data-[slot=checkbox-group]:gap-3 *:data-[slot=field-group]:gap-4 group/field-group @container/field-group flex w-full flex-col", props.className)}
        />;
    }

    def:pub Field(props: Any) -> JsxElement {
        orientation = props.orientation or "vertical";
        variantsFn = _fieldVariants;
        return <div
            {...props}
            role="group"
            data-slot="field"
            data-orientation={orientation}
            className={cn(variantsFn.call(None, {"orientation": orientation}), props.className)}
        />;
    }

    def:pub FieldContent(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="field-content"
            className={cn("gap-0.5 gap-0.5 group/field-content flex flex-1 flex-col leading-snug", props.className)}
        />;
    }

    def:pub FieldLabel(props: Any) -> JsxElement {
        return <Label
            {...props}
            data-slot="field-label"
            className={cn("has-data-checked:bg-primary/5 has-data-checked:border-primary/30 dark:has-data-checked:border-primary/20 dark:has-data-checked:bg-primary/10 gap-2 group-data-[disabled=true]/field:opacity-50 has-[>[data-slot=field]]:rounded-lg has-[>[data-slot=field]]:border *:data-[slot=field]:p-2.5 has-data-checked:bg-primary/5 has-data-checked:border-primary/30 dark:has-data-checked:border-primary/20 dark:has-data-checked:bg-primary/10 gap-2 group-data-[disabled=true]/field:opacity-50 has-[>[data-slot=field]]:rounded-lg has-[>[data-slot=field]]:border *:data-[slot=field]:p-2.5 group/field-label peer/field-label flex w-fit leading-snug", "has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col", props.className)}
        />;
    }

    def:pub FieldTitle(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="field-label"
            className={cn("gap-2 text-sm font-medium group-data-[disabled=true]/field:opacity-50 gap-2 text-sm font-medium group-data-[disabled=true]/field:opacity-50 flex w-fit items-center leading-snug", props.className)}
        />;
    }

    def:pub FieldDescription(props: Any) -> JsxElement {
        return <p
            {...props}
            data-slot="field-description"
            className={cn("text-muted-foreground text-left text-sm [[data-variant=legend]+&]:-mt-1.5 text-muted-foreground text-left text-sm [[data-variant=legend]+&]:-mt-1.5 leading-normal font-normal group-has-data-horizontal/field:text-balance", "last:mt-0 nth-last-2:-mt-1", "[&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4", props.className)}
        />;
    }

    def:pub FieldSeparator(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="field-separator"
            data-content={Boolean(props.children)}
            className={cn("-my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2 -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2 relative", props.className)}
        >
            <Separator className="absolute inset-0 top-1/2" />
            {props.children and (
                <span className="text-muted-foreground px-2 bg-background relative mx-auto block w-fit" data-slot="field-separator-content">
                    {props.children}
                </span>
            )}
        </div>;
    }

    def:pub FieldError(props: Any) -> Any {
        children = props.children;
        errors = props.errors;

        content = useMemo(lambda -> Any {
            if children {
                return children;
            }
            if not errors or not errors.length {
                return None;
            }
            uniqueMap = Reflect.construct(Map, [errors.map(lambda(error: Any) -> Any { return [error and error.message, error]; })]);
            uniqueErrors = Array.from(uniqueMap.values());
            if uniqueErrors.length == 1 {
                return uniqueErrors[0] and uniqueErrors[0].message;
            }
            return <ul className="ml-4 flex list-disc flex-col gap-1">
                {uniqueErrors.map(lambda(error: Any, index: Any) -> Any {
                    if error and error.message {
                        return <li key={index}>{error.message}</li>;
                    }
                    return None;
                })}
            </ul>;
        }, [children, errors]);

        if not content {
            return None;
        }

        return <div
            {...props}
            role="alert"
            data-slot="field-error"
            className={cn("text-destructive text-sm text-destructive text-sm font-normal", props.className)}
        >
            {content}
        </div>;
    }
}
