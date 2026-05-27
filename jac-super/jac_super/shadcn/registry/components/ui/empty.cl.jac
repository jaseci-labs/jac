cl import from "class-variance-authority" { cva }
cl import from ...lib.utils { cn }

glob _emptyMediaVariants: Any = cva(
         "cn-empty-media flex shrink-0 items-center justify-center [&_svg]:pointer-events-none [&_svg]:shrink-0",
         {
             "variants": {
                 "variant": {
                     "default": "cn-empty-media-default",
                     "icon": "cn-empty-media-icon"
                 }
             },
             "defaultVariants": {"variant": "default"}
         }
     );

cl {
    def:pub Empty(props: Any) -> JsxElement {
        return
            <div
                data-slot="empty"
                className={cn(
                    "cn-empty flex w-full min-w-0 flex-1 flex-col items-center justify-center text-center text-balance",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub EmptyHeader(props: Any) -> JsxElement {
        return
            <div
                data-slot="empty-header"
                className={cn(
                    "cn-empty-header flex max-w-sm flex-col items-center",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub EmptyMedia(props: Any) -> JsxElement {
        variant = props.variant or "default";
        computedClass = cn(
            _emptyMediaVariants.call(
                None, {"variant": variant, "className": props.className}
            )
        );
        return
            <div
                data-slot="empty-icon"
                data-variant={variant}
                className={computedClass}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub EmptyTitle(props: Any) -> JsxElement {
        return
            <div
                data-slot="empty-title"
                className={cn("cn-empty-title", props.className)}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub EmptyDescription(props: Any) -> JsxElement {
        return
            <div
                data-slot="empty-description"
                className={cn(
                    "cn-empty-description text-muted-foreground [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }

    def:pub EmptyContent(props: Any) -> JsxElement {
        return
            <div
                data-slot="empty-content"
                className={cn(
                    "cn-empty-content flex w-full max-w-sm min-w-0 flex-col items-center text-balance",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </div>;
    }
}
