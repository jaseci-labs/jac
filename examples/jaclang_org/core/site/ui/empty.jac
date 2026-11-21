import from "class-variance-authority" { cva }

glob _emptyMediaVariants: any = cva(
    "mb-2 flex shrink-0 items-center justify-center [&_svg]:pointer-events-none [&_svg]:shrink-0",
    {
        "variants": {
            "variant": {
                "default": "bg-transparent",
                "icon": "bg-muted text-foreground flex size-8 shrink-0 items-center justify-center rounded-lg [&_svg:not([class*='size-'])]:size-4",
            },
        },
        "defaultVariants": {"variant": "default"},
    },
);

def:pub Empty(**kwargs: any) -> JsxElement;

def:pub EmptyHeader(**kwargs: any) -> JsxElement;

def:pub EmptyMedia(**kwargs: any) -> JsxElement;

def:pub EmptyTitle(**kwargs: any) -> JsxElement;

def:pub EmptyDescription(**kwargs: any) -> JsxElement;

def:pub EmptyContent(**kwargs: any) -> JsxElement;
