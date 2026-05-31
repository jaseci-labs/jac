cl import from "radix-ui" { ToggleGroup as ToggleGroupPrimitive }
cl import from ...lib.utils { cn }
cl import from ".toggle" { toggleVariants }

cl {
    def:pub ToggleGroup(props: any) -> JsxElement {
        variant = props["variant"] or "default";
        size = props["size"] or "default";
        spacing = props["spacing"] or 0;
        orientation = props["orientation"] or "horizontal";

        return
            <ToggleGroupPrimitive.Root
                {**props}
                data-slot="toggle-group"
                data-variant={variant}
                data-size={size}
                data-spacing={spacing}
                data-orientation={orientation}
                className={cn(
                    "cn-toggle-group group/toggle-group flex w-fit flex-row items-center data-vertical:flex-col data-vertical:items-stretch",
                    props["className"]
                )}
            >
                {props["children"]}
            </ToggleGroupPrimitive.Root>;
    }

    def:pub ToggleGroupItem(props: any) -> JsxElement {
        variant = props["variant"] or "default";
        size = props["size"] or "default";
        variantsFn: any = toggleVariants();
        computedClass = cn(
            "cn-toggle-group-item shrink-0 focus:z-10 focus-visible:z-10",
            variantsFn.call(None, {"variant": variant, "size": size}),
            props["className"]
        );
        return
            <ToggleGroupPrimitive.Item
                {**props}
                data-slot="toggle-group-item"
                data-variant={variant}
                data-size={size}
                className={computedClass}
            >
                {props["children"]}
            </ToggleGroupPrimitive.Item>;
    }
}
