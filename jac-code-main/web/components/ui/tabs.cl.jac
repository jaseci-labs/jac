cl import from "radix-ui" { Tabs as TabsPrimitive }
cl import from "class-variance-authority" { cva }
cl import from ...lib.utils { cn }

glob _tabsListVariants: Any = cva(
    "rounded-lg p-[3px] group-data-horizontal/tabs:h-8 data-[variant=line]:rounded-none group/tabs-list text-muted-foreground inline-flex w-fit items-center justify-center group-data-vertical/tabs:h-fit group-data-vertical/tabs:flex-col",
    {
        "variants": {
            "variant": {
                "default": "rounded-lg p-[3px] group-data-horizontal/tabs:h-8 data-[variant=line]:rounded-none-variant-default bg-muted",
                "line": "rounded-lg p-[3px] group-data-horizontal/tabs:h-8 data-[variant=line]:rounded-none-variant-line gap-1 bg-transparent"
            }
        },
        "defaultVariants": {
            "variant": "default"
        }
    }
);

cl {
    def:pub Tabs(props: Any) -> JsxElement {
        orientation = props.orientation or "horizontal";
        return <TabsPrimitive.Root
            {...props}
            data-slot="tabs"
            data-orientation={orientation}
            className={cn("gap-2 group/tabs flex data-horizontal:flex-col", props.className)}
        />;
    }

    def:pub TabsList(props: Any) -> JsxElement {
        variant = props.variant or "default";
        return <TabsPrimitive.List
            {...props}
            data-slot="tabs-list"
            data-variant={variant}
            className={cn(_tabsListVariants.call(None, {"variant": variant}), props.className)}
        />;
    }

    def:pub TabsTrigger(props: Any) -> JsxElement {
        return <TabsPrimitive.Trigger
            {...props}
            data-slot="tabs-trigger"
            className={cn(
                "gap-1.5 rounded-md border border-transparent px-1.5 py-0.5 text-sm font-medium group-data-[variant=default]/tabs-list:data-active:shadow-sm group-data-[variant=line]/tabs-list:data-active:shadow-none [&_svg:not([class*='size-'])]:size-4 focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:outline-ring text-foreground/60 hover:text-foreground dark:text-muted-foreground dark:hover:text-foreground relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center whitespace-nowrap transition-all group-data-vertical/tabs:w-full group-data-vertical/tabs:justify-start focus-visible:ring-[3px] focus-visible:outline-1 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
                "group-data-[variant=line]/tabs-list:bg-transparent group-data-[variant=line]/tabs-list:data-active:bg-transparent dark:group-data-[variant=line]/tabs-list:data-active:border-transparent dark:group-data-[variant=line]/tabs-list:data-active:bg-transparent",
                "data-active:bg-background dark:data-active:text-foreground dark:data-active:border-input dark:data-active:bg-input/30 data-active:text-foreground",
                "after:bg-foreground after:absolute after:opacity-0 after:transition-opacity group-data-horizontal/tabs:after:inset-x-0 group-data-horizontal/tabs:after:bottom-[-5px] group-data-horizontal/tabs:after:h-0.5 group-data-vertical/tabs:after:inset-y-0 group-data-vertical/tabs:after:-right-1 group-data-vertical/tabs:after:w-0.5 group-data-[variant=line]/tabs-list:data-active:after:opacity-100",
                props.className
            )}
        />;
    }

    def:pub TabsContent(props: Any) -> JsxElement {
        return <TabsPrimitive.Content
            {...props}
            data-slot="tabs-content"
            className={cn("text-sm flex-1 outline-none", props.className)}
        />;
    }

    def:pub tabsListVariants() -> Any {
        return _tabsListVariants;
    }
}
