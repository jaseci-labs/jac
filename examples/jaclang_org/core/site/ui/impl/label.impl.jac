impl Label(**kwargs: any) -> JsxElement {
    return <LabelPrimitive.Root
        {...kwargs}
        data-slot="label"
        className={cn("flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50", kwargs.get("className"))}
    />;
}
