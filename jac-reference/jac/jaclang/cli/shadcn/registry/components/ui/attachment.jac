import from "class-variance-authority" { cva }
import from "radix-ui" { Slot }
import from .button { Button }
import from ...lib.utils { cn }

glob _attachmentVariants: any = cva(
         "cn-attachment group/attachment relative flex max-w-full min-w-0 shrink-0 flex-wrap border bg-card text-card-foreground transition-colors has-[>a,>button]:hover:bg-muted/50 data-[state=error]:border-destructive/30 data-[state=idle]:border-dashed",
         {
             "variants": {
                 "size": {
                     "default": "cn-attachment-size-default",
                     "sm": "cn-attachment-size-sm",
                     "xs": "cn-attachment-size-xs"
                 },
                 "orientation": {
                     "horizontal": "cn-attachment-orientation-horizontal items-center",
                     "vertical": "cn-attachment-orientation-vertical flex-col"
                 }
             }
         }
     ),
     _attachmentMediaVariants: any = cva(
         "cn-attachment-media relative flex aspect-square shrink-0 items-center justify-center overflow-hidden group-data-[state=error]/attachment:bg-destructive/10 group-data-[state=error]/attachment:text-destructive [&_svg]:pointer-events-none",
         {
             "variants": {
                 "variant": {
                     "icon": "cn-attachment-media-variant-icon",
                     "image": "cn-attachment-media-variant-image *:[img]:aspect-square *:[img]:w-full *:[img]:object-cover"
                 }
             },
             "defaultVariants": {"variant": "icon"}
         }
     ),
     _attachmentExcludeKeys: list[str] = [
         "className",
         "state",
         "size",
         "orientation",
         "children"
     ],
     _attachmentMediaExcludeKeys: list[str] = ["className", "variant", "children"],
     _attachmentActionExcludeKeys: list[str] = ["className", "variant", "size"],
     _attachmentTriggerExcludeKeys: list[str] = [
         "className",
         "asChild",
         "type",
         "children"
     ];

def:pub Attachment(props: any) -> JsxElement {
    state = props["state"] or "done";
    size = props["size"] or "default";
    orientation = props["orientation"] or "horizontal";
    computedClass = cn(
        _attachmentVariants.call(None, {"size": size, "orientation": orientation}),
        props["className"]
    );

    restProps = {};
    for key in Object.keys(props) {
        if key not in _attachmentExcludeKeys {
            restProps[key] = props[key];
        }
    }

    <div
        data-slot="attachment"
        data-state={state}
        data-size={size}
        data-orientation={orientation}
        className={computedClass}
        {**restProps}
    >
        {props["children"]}
    </div>
}

def:pub AttachmentMedia(props: any) -> JsxElement {
    variant = props["variant"] or "icon";
    computedClass = cn(
        _attachmentMediaVariants.call(None, {"variant": variant}), props["className"]
    );

    restProps = {};
    for key in Object.keys(props) {
        if key not in _attachmentMediaExcludeKeys {
            restProps[key] = props[key];
        }
    }

    <div
        data-slot="attachment-media"
        data-variant={variant}
        className={computedClass}
        {**restProps}
    >
        {props["children"]}
    </div>
}

def:pub AttachmentContent(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="attachment-content"
        className={cn(
            "cn-attachment-content max-w-full min-w-0 flex-1", props["className"]
        )}
    />
}

def:pub AttachmentTitle(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <span
        {**attrs}
        data-slot="attachment-title"
        className={cn(
            "cn-attachment-title block max-w-full min-w-0 truncate group-data-[state=processing]/attachment:shimmer group-data-[state=uploading]/attachment:shimmer",
            props["className"]
        )}
    />
}

def:pub AttachmentDescription(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <span
        {**attrs}
        data-slot="attachment-description"
        className={cn(
            "cn-attachment-description block min-w-0 truncate text-muted-foreground group-data-[state=error]/attachment:text-destructive/80",
            "max-w-full",
            props["className"]
        )}
    />
}

def:pub AttachmentActions(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="attachment-actions"
        className={cn(
            "cn-attachment-actions flex shrink-0 items-center", props["className"]
        )}
    />
}

def:pub AttachmentAction(props: any) -> JsxElement {
    variant = props["variant"] or "ghost";
    size = props["size"] or "icon-xs";

    restProps = {};
    for key in Object.keys(props) {
        if key not in _attachmentActionExcludeKeys {
            restProps[key] = props[key];
        }
    }

    <Button
        data-slot="attachment-action"
        variant={variant}
        size={size}
        className={cn("cn-attachment-action", props["className"])}
        {**restProps}
    />
}

def:pub AttachmentTrigger(props: any) -> JsxElement {
    asChild = props["asChild"] or False;
    computedClass = cn(
        "cn-attachment-trigger absolute inset-0 z-10 outline-none", props["className"]
    );

    restProps = {};
    for key in Object.keys(props) {
        if key not in _attachmentTriggerExcludeKeys {
            restProps[key] = props[key];
        }
    }

    if asChild {
        return
            <Slot.Root
                data-slot="attachment-trigger"
                className={computedClass}
                {**restProps}
            >
                {props["children"]}
            </Slot.Root>;
    }
    <button
        data-slot="attachment-trigger"
        type={props["type"] or "button"}
        className={computedClass}
        {**restProps}
    >
        {props["children"]}
    </button>
}

def:pub AttachmentGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="attachment-group"
        className={cn(
            "cn-attachment-group flex min-w-0 scroll-fade-x snap-x snap-mandatory scrollbar-none overflow-x-auto overscroll-x-contain *:data-[slot=attachment]:flex-none *:data-[slot=attachment]:snap-start",
            props["className"]
        )}
    />
}
