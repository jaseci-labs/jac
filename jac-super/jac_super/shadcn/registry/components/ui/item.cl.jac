cl import from "class-variance-authority" { cva }
cl import from "radix-ui" { Slot }
cl import from ...lib.utils { cn }
cl import from .separator { Separator }

glob _itemVariants: Any = cva(
         "cn-item w-full group/item focus-visible:border-ring focus-visible:ring-ring/50 flex items-center flex-wrap outline-none transition-colors duration-100 focus-visible:ring-[3px]",
         {
             "variants": {
                 "variant": {
                     "default": "cn-item-variant-default",
                     "outline": "cn-item-variant-outline",
                     "muted": "cn-item-variant-muted"
                 },
                 "size": {
                     "default": "cn-item-size-default",
                     "sm": "cn-item-size-sm",
                     "xs": "cn-item-size-xs"
                 }
             },
             "defaultVariants": {"variant": "default", "size": "default"}
         }
     ),
     _itemMediaVariants: Any = cva(
         "cn-item-media flex shrink-0 items-center justify-center [&_svg]:pointer-events-none",
         {
             "variants": {
                 "variant": {
                     "default": "cn-item-media-variant-default",
                     "icon": "cn-item-media-variant-icon",
                     "image": "cn-item-media-variant-image"
                 }
             },
             "defaultVariants": {"variant": "default"}
         }
     ),
     _itemExcludeKeys: list = ["className", "variant", "size", "asChild", "children"];

cl {
    def:pub ItemGroup(props: Any) -> JsxElement {
        return
            <div
                role="list"
                data-slot="item-group"
                className={cn(
                    "cn-item-group group/item-group flex w-full flex-col",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub ItemSeparator(props: Any) -> JsxElement {
        return
            <Separator
                data-slot="item-separator"
                orientation="horizontal"
                className={cn("cn-item-separator", props.className)}
                {...props}
            />;
    }

    def:pub Item(props: Any) -> JsxElement {
        variant = props.variant or "default";
        size = props.size or "default";
        asChild = props.asChild or False;
        computedClass = cn(
            _itemVariants.call(
                None, {"variant": variant, "size": size, "className": props.className}
            )
        );

        restProps = {};
        excludeKeys = _itemExcludeKeys;
        Object.keys(props).forEach(
            lambda (key: Any) { if excludeKeys.indexOf(key) == -1 {
                restProps[key] = props[key];
            }}
        );

        if asChild {
            return
                <Slot.Root
                    data-slot="item"
                    data-variant={variant}
                    data-size={size}
                    className={computedClass}
                    {...restProps}
                >
                    {props.children}
                </Slot.Root>;
        }
        return
            <div
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
        computedClass = cn(
            _itemMediaVariants.call(
                None, {"variant": variant, "className": props.className}
            )
        );
        return
            <div
                data-slot="item-media"
                data-variant={variant}
                className={computedClass}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub ItemContent(props: Any) -> JsxElement {
        return
            <div
                data-slot="item-content"
                className={cn(
                    "cn-item-content flex flex-1 flex-col [&+[data-slot=item-content]]:flex-none",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub ItemTitle(props: Any) -> JsxElement {
        return
            <div
                data-slot="item-title"
                className={cn(
                    "cn-item-title line-clamp-1 flex w-fit items-center",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub ItemDescription(props: Any) -> JsxElement {
        return
            <p
                data-slot="item-description"
                className={cn(
                    "cn-item-description line-clamp-2 font-normal [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </p>;
    }

    def:pub ItemActions(props: Any) -> JsxElement {
        return
            <div
                data-slot="item-actions"
                className={cn("cn-item-actions flex items-center", props.className)}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub ItemHeader(props: Any) -> JsxElement {
        return
            <div
                data-slot="item-header"
                className={cn(
                    "cn-item-header flex basis-full items-center justify-between",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub ItemFooter(props: Any) -> JsxElement {
        return
            <div
                data-slot="item-footer"
                className={cn(
                    "cn-item-footer flex basis-full items-center justify-between",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub itemVariants -> Any {
        return _itemVariants;
    }
}
