import from "class-variance-authority" { cva }
import from "radix-ui" { Slot }
import from ...lib.utils { cn }
import from .separator { Separator }

glob _itemVariants: any = cva(
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
     _itemMediaVariants: any = cva(
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
     _itemExcludeKeys: list[str] = [
         "className",
         "variant",
         "size",
         "asChild",
         "children"
     ];

def:pub ItemGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            role="list"
            data-slot="item-group"
            className={cn(
                "cn-item-group group/item-group flex w-full flex-col",
                props["className"]
            )}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub ItemSeparator(props: any) -> JsxElement {
    return
        <Separator
            data-slot="item-separator"
            orientation="horizontal"
            className={cn("cn-item-separator", props["className"])}
            {**props}
        />;
}

def:pub Item(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    size = props["size"] or "default";
    asChild = props["asChild"] or False;
    computedClass = cn(
        _itemVariants.call(
            None, {"variant": variant, "size": size, "className": props["className"]}
        )
    );

    restProps = {};
    for key in Object.keys(props) {  # jac:ignore[W6001]
        if key not in _itemExcludeKeys {
            restProps[key] = props[key];
        }
    }

    if asChild {
        return
            <Slot.Root
                data-slot="item"
                data-variant={variant}
                data-size={size}
                className={computedClass}
                {**restProps}
            >
                {props["children"]}
            </Slot.Root>;
    }
    return
        <div
            data-slot="item"
            data-variant={variant}
            data-size={size}
            className={computedClass}
            {**restProps}
        >
            {props["children"]}
        </div>;
}

def:pub ItemMedia(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    variant = props["variant"] or "default";
    computedClass = cn(
        _itemMediaVariants.call(
            None, {"variant": variant, "className": props["className"]}
        )
    );
    return
        <div
            data-slot="item-media"
            data-variant={variant}
            className={computedClass}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub ItemContent(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            data-slot="item-content"
            className={cn(
                "cn-item-content flex flex-1 flex-col [&+[data-slot=item-content]]:flex-none",
                props["className"]
            )}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub ItemTitle(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            data-slot="item-title"
            className={cn(
                "cn-item-title line-clamp-1 flex w-fit items-center", props["className"]
            )}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub ItemDescription(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <p
            data-slot="item-description"
            className={cn(
                "cn-item-description line-clamp-2 font-normal [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
                props["className"]
            )}
            {**attrs}
        >
            {props["children"]}
        </p>;
}

def:pub ItemActions(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            data-slot="item-actions"
            className={cn("cn-item-actions flex items-center", props["className"])}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub ItemHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            data-slot="item-header"
            className={cn(
                "cn-item-header flex basis-full items-center justify-between",
                props["className"]
            )}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub ItemFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            data-slot="item-footer"
            className={cn(
                "cn-item-footer flex basis-full items-center justify-between",
                props["className"]
            )}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub itemVariants -> any {
    return _itemVariants;
}
