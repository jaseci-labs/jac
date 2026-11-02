import from "react" { useMemo }
import from "class-variance-authority" { cva }

glob _fieldVariants: any = cva(
         "data-[invalid=true]:text-destructive gap-2 data-[invalid=true]:text-destructive gap-2 group/field flex w-full",
         {
             "variants": {
                 "orientation": {
                     "vertical": "data-[invalid=true]:text-destructive gap-2-orientation-vertical flex-col *:w-full [&>.sr-only]:w-auto",
                     "horizontal": "data-[invalid=true]:text-destructive gap-2-orientation-horizontal flex-row items-center *:data-[slot=field-label]:flex-auto has-[>[data-slot=field-content]]:items-start has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px",
                     "responsive": "data-[invalid=true]:text-destructive gap-2-orientation-responsive flex-col *:w-full [&>.sr-only]:w-auto @md/field-group:flex-row @md/field-group:items-center @md/field-group:*:w-auto @md/field-group:*:data-[slot=field-label]:flex-auto @md/field-group:has-[>[data-slot=field-content]]:items-start @md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
                 }
             },
             "defaultVariants": {"orientation": "vertical"}
         }
     );

def:pub FieldSet(props: any) -> JsxElement;

def:pub FieldLegend(props: any) -> JsxElement;

def:pub FieldGroup(props: any) -> JsxElement;

def:pub Field(props: any) -> JsxElement;

def:pub FieldContent(props: any) -> JsxElement;

def:pub FieldLabel(props: any) -> JsxElement;

def:pub FieldTitle(props: any) -> JsxElement;

def:pub FieldDescription(props: any) -> JsxElement;

def:pub FieldSeparator(props: any) -> JsxElement;

def:pub FieldError(props: any) -> any;
