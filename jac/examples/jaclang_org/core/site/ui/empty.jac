import from "class-variance-authority" { cva }
import from ....core.utils { cn }

glob _emptyMediaVariants: any = cva(
         "mb-2 flex shrink-0 items-center justify-center [&_svg]:pointer-events-none [&_svg]:shrink-0",
         {
             "variants": {
                 "variant": {
                     "default": "bg-transparent",
                     "icon": "bg-muted text-foreground flex size-8 shrink-0 items-center justify-center rounded-lg [&_svg:not([class*='size-'])]:size-4"
                 }
             },
             "defaultVariants": {"variant": "default"}
         }
     );

def:pub Empty(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty"
        className={cn(
            "gap-4 rounded-xl border-dashed p-6 flex w-full min-w-0 flex-1 flex-col items-center justify-center text-center text-balance",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}

def:pub EmptyHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-header"
        className={cn("gap-2 flex max-w-sm flex-col items-center", props["className"])}
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
        {**attrs}
        data-slot="empty-icon"
        data-variant={variant}
        className={computedClass}
    >
        {props["children"]}
    </div>
}

def:pub EmptyTitle(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-title"
        className={cn("text-sm font-medium tracking-tight", props["className"])}
    >
        {props["children"]}
    </div>
}

def:pub EmptyDescription(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-description"
        className={cn(
            "text-sm/relaxed text-muted-foreground [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}

def:pub EmptyContent(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-content"
        className={cn(
            "gap-2.5 text-sm flex w-full max-w-sm min-w-0 flex-col items-center text-balance",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}
