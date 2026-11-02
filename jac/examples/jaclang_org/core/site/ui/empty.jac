import from "class-variance-authority" { cva }

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

def:pub Empty(props: any) -> JsxElement;

def:pub EmptyHeader(props: any) -> JsxElement;

def:pub EmptyMedia(props: any) -> JsxElement;

def:pub EmptyTitle(props: any) -> JsxElement;

def:pub EmptyDescription(props: any) -> JsxElement;

def:pub EmptyContent(props: any) -> JsxElement;
