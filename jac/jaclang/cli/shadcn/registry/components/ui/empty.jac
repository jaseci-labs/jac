import from "class-variance-authority" { cva }
import from ...lib.utils { cn }

glob _emptyMediaVariants: any = cva(
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

def:pub Empty(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        data-slot="empty"
        {**attrs}
        className={cn(
            "cn-empty flex w-full min-w-0 flex-1 flex-col items-center justify-center text-center text-balance",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}

def:pub EmptyHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        data-slot="empty-header"
        {**attrs}
        className={cn(
            "cn-empty-header flex max-w-sm flex-col items-center", props["className"]
        )}
    >
        {props["children"]}
    </div>
}

def:pub EmptyMedia(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    variant = props["variant"] or "default";
    computedClass = cn(
        _emptyMediaVariants.call(
            None, {"variant": variant, "className": props["className"]}
        )
    );
    <div
        data-slot="empty-icon"
        data-variant={variant}
        {**attrs}
        className={computedClass}
    >
        {props["children"]}
    </div>
}

def:pub EmptyTitle(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        data-slot="empty-title"
        {**attrs}
        className={cn("cn-empty-title", props["className"])}
    >
        {props["children"]}
    </div>
}

def:pub EmptyDescription(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        data-slot="empty-description"
        {**attrs}
        className={cn(
            "cn-empty-description text-muted-foreground [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}

def:pub EmptyContent(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        data-slot="empty-content"
        {**attrs}
        className={cn(
            "cn-empty-content flex w-full max-w-sm min-w-0 flex-col items-center text-balance",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}
