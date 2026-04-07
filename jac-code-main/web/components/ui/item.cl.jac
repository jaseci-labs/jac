cl import from "class-variance-authority" { cva }
cl import from "radix-ui" { Slot }
cl import from ...lib.utils { cn }
cl import from .separator { Separator }

glob _itemVariants: Any = cva(
    "[a]:hover:bg-muted rounded-lg border text-sm w-full group/item focus-visible:border-ring focus-visible:ring-ring/50 flex items-center flex-wrap outline-none transition-colors duration-100 focus-visible:ring-[3px]",
    {
        "variants": {
            "variant": {
                "default": "border-transparent",
                "outline": "border-border",
                "muted": "bg-muted/50 border-transparent"
            },
            "size": {
                "default": "gap-2.5 px-3 py-2.5",
                "sm": "gap-2.5 px-3 py-2.5",
                "xs": "gap-2 px-2.5 py-2 in-data-[slot=dropdown-menu-content]:p-0"
            }
        },
        "defaultVariants": {
            "variant": "default",
            "size": "default"
        }
    }
);

glob _itemMediaVariants: Any = cva(
    "gap-2 group-has-data-[slot=item-description]/item:translate-y-0.5 group-has-data-[slot=item-description]/item:self-start flex shrink-0 items-center justify-center [&_svg]:pointer-events-none",
    {
        "variants": {
            "variant": {
                "default": "bg-transparent",
                "icon": "[&_svg:not([class*='size-'])]:size-4",
                "image": "size-10 overflow-hidden rounded-sm group-data-[size=sm]/item:size-8 group-data-[size=xs]/item:size-6 [&_img]:size-full [&_img]:object-cover"
            }
        },
        "defaultVariants": {
            "variant": "default"
        }
    }
);

glob _itemExcludeKeys: list = ["className", "variant", "size", "asChild", "children"];

cl {
    def:pub ItemGroup(props: Any) -> JsxElement {
        return <div
            role="list"
            data-slot="item-group"
            className={cn("gap-4 has-data-[size=sm]:gap-2.5 has-data-[size=xs]:gap-2 group/item-group flex w-full flex-col", props.className)}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ItemSeparator(props: Any) -> JsxElement {
        return <Separator
            data-slot="item-separator"
            orientation="horizontal"
            className={cn("my-2", props.className)}
            {...props}
        />;
    }

    def:pub Item(props: Any) -> JsxElement {
        variant = props.variant or "default";
        size = props.size or "default";
        asChild = props.asChild or False;
        computedClass = cn(_itemVariants.call(None, {"variant": variant, "size": size, "className": props.className}));

        restProps = {};
        excludeKeys = _itemExcludeKeys;
        Object.keys(props).forEach(lambda(key: Any) -> None {
            if excludeKeys.indexOf(key) == -1 {
                restProps[key] = props[key];
            }
        });

        if asChild {
            return <Slot.Root
                data-slot="item"
                data-variant={variant}
                data-size={size}
                className={computedClass}
                {...restProps}
            >
                {props.children}
            </Slot.Root>;
        }
        return <div
            data-slot="item"
            data-variant={variant}
            data-size={size}
            className={computedClass}
            {...restProps}
        >
            {props.children}
        </div>;
    }

    def:pub ItemMedia(props: Any) -> JsxElement {
        variant = props.variant or "default";
        computedClass = cn(_itemMediaVariants.call(None, {"variant": variant, "className": props.className}));
        return <div
            data-slot="item-media"
            data-variant={variant}
            className={computedClass}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ItemContent(props: Any) -> JsxElement {
        return <div
            data-slot="item-content"
            className={cn("gap-1 group-data-[size=xs]/item:gap-0 flex flex-1 flex-col [&+[data-slot=item-content]]:flex-none", props.className)}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ItemTitle(props: Any) -> JsxElement {
        return <div
            data-slot="item-title"
            className={cn("gap-2 text-sm leading-snug font-medium underline-offset-4 line-clamp-1 flex w-fit items-center", props.className)}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ItemDescription(props: Any) -> JsxElement {
        return <p
            data-slot="item-description"
            className={cn("text-muted-foreground text-left text-sm leading-normal group-data-[size=xs]/item:text-xs line-clamp-2 font-normal [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4", props.className)}
            {...props}
        >
            {props.children}
        </p>;
    }

    def:pub ItemActions(props: Any) -> JsxElement {
        return <div
            data-slot="item-actions"
            className={cn("gap-2 flex items-center", props.className)}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ItemHeader(props: Any) -> JsxElement {
        return <div
            data-slot="item-header"
            className={cn("gap-2 flex basis-full items-center justify-between", props.className)}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ItemFooter(props: Any) -> JsxElement {
        return <div
            data-slot="item-footer"
            className={cn("gap-2 flex basis-full items-center justify-between", props.className)}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub itemVariants() -> Any {
        return _itemVariants;
    }
}
