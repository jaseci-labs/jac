import from "radix-ui" { Tabs as TabsPrimitive }
import from "class-variance-authority" { cva }

glob _tabsListVariants: any = cva(
         "rounded-lg p-[3px] group-data-horizontal/tabs:h-8 data-[variant=line]:rounded-none group/tabs-list text-muted-foreground inline-flex w-fit items-center justify-center group-data-vertical/tabs:h-fit group-data-vertical/tabs:flex-col",
         {
             "variants": {
                 "variant": {
                     "default": "rounded-lg p-[3px] group-data-horizontal/tabs:h-8 data-[variant=line]:rounded-none-variant-default bg-muted",
                     "line": "rounded-lg p-[3px] group-data-horizontal/tabs:h-8 data-[variant=line]:rounded-none-variant-line gap-1 bg-transparent"
                 }
             },
             "defaultVariants": {"variant": "default"}
         }
     );

def:pub Tabs(props: any) -> JsxElement;

def:pub TabsList(props: any) -> JsxElement;

def:pub TabsTrigger(props: any) -> JsxElement;

def:pub TabsContent(props: any) -> JsxElement;

def:pub tabsListVariants -> any;

impl tabsListVariants -> any {
    return _tabsListVariants;
}
