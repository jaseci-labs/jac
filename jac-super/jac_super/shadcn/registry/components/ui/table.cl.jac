import from ...lib.utils { cn }

def:pub Table(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div data-slot="table-container" className="cn-table-container">
            <table
                {**attrs}
                data-slot="table"
                className={cn("cn-table", props["className"])}
            />
        </div>;
}

def:pub TableHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <thead
            {**attrs}
            data-slot="table-header"
            className={cn("cn-table-header", props["className"])}
        />;
}

def:pub TableBody(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <tbody
            {**attrs}
            data-slot="table-body"
            className={cn("cn-table-body", props["className"])}
        />;
}

def:pub TableFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <tfoot
            {**attrs}
            data-slot="table-footer"
            className={cn("cn-table-footer", props["className"])}
        />;
}

def:pub TableRow(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <tr
            {**attrs}
            data-slot="table-row"
            className={cn("cn-table-row", props["className"])}
        />;
}

def:pub TableHead(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <th
            {**attrs}
            data-slot="table-head"
            className={cn("cn-table-head", props["className"])}
        />;
}

def:pub TableCell(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <td
            {**attrs}
            data-slot="table-cell"
            className={cn("cn-table-cell", props["className"])}
        />;
}

def:pub TableCaption(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <caption
            {**attrs}
            data-slot="table-caption"
            className={cn("cn-table-caption", props["className"])}
        />;
}
