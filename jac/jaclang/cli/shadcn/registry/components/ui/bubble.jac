import from "class-variance-authority" { cva }
import from "radix-ui" { Slot }
import from ...lib.utils { cn }

glob _bubbleVariants: any = cva(
         "cn-bubble group/bubble relative flex w-fit min-w-0 flex-col",
         {
             "variants": {
                 "variant": {
                     "default": "cn-bubble-variant-default",
                     "secondary": "cn-bubble-variant-secondary",
                     "muted": "cn-bubble-variant-muted",
                     "tinted": "cn-bubble-variant-tinted",
                     "outline": "cn-bubble-variant-outline",
                     "ghost": "cn-bubble-variant-ghost",
                     "destructive": "cn-bubble-variant-destructive"
                 }
             },
             "defaultVariants": {"variant": "default"}
         }
     ),
     _bubbleReactionsVariants: any = cva(
         "cn-bubble-reactions absolute z-10 flex w-fit items-center justify-center",
         {
             "variants": {
                 "side": {
                     "top": "cn-bubble-reactions-side-top",
                     "bottom": "cn-bubble-reactions-side-bottom"
                 },
                 "align": {
                     "start": "cn-bubble-reactions-align-start",
                     "end": "cn-bubble-reactions-align-end"
                 }
             },
             "defaultVariants": {"side": "bottom", "align": "end"}
         }
     ),
     _bubbleExcludeKeys: list[str] = ["className", "variant", "align", "children"],
     _bubbleContentExcludeKeys: list[str] = ["className", "asChild", "children"],
     _bubbleReactionsExcludeKeys: list[str] = [
         "className",
         "side",
         "align",
         "children"
     ];

def:pub BubbleGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="bubble-group"
        className={cn("cn-bubble-group flex min-w-0 flex-col", props["className"])}
    />
}

def:pub Bubble(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    align = props["align"] or "start";
    computedClass = cn(
        _bubbleVariants.call(None, {"variant": variant}), props["className"]
    );

    restProps = {};
    for key in Object.keys(props) {
        if key not in _bubbleExcludeKeys {
            restProps[key] = props[key];
        }
    }

    <div
        data-slot="bubble"
        data-variant={variant}
        data-align={align}
        className={computedClass}
        {**restProps}
    >
        {props["children"]}
    </div>
}

def:pub BubbleContent(props: any) -> JsxElement {
    asChild = props["asChild"] or False;
    computedClass = cn(
        "cn-bubble-content w-fit max-w-full min-w-0 overflow-hidden wrap-break-word [button]:text-left [button,a]:transition-colors",
        props["className"]
    );

    restProps = {};
    for key in Object.keys(props) {
        if key not in _bubbleContentExcludeKeys {
            restProps[key] = props[key];
        }
    }

    if asChild {
        return
            <Slot.Root
                data-slot="bubble-content"
                className={computedClass}
                {**restProps}
            >
                {props["children"]}
            </Slot.Root>;
    }
    <div data-slot="bubble-content" className={computedClass} {**restProps}>
        {props["children"]}
    </div>
}

def:pub BubbleReactions(props: any) -> JsxElement {
    side = props["side"] or "bottom";
    align = props["align"] or "end";
    computedClass = cn(
        _bubbleReactionsVariants.call(None, {"side": side, "align": align}),
        props["className"]
    );

    restProps = {};
    for key in Object.keys(props) {
        if key not in _bubbleReactionsExcludeKeys {
            restProps[key] = props[key];
        }
    }

    <div
        data-slot="bubble-reactions"
        data-align={align}
        data-side={side}
        className={computedClass}
        {**restProps}
    >
        {props["children"]}
    </div>
}
