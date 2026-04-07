cl import from ...lib.utils { cn }

cl {
    def:pub Table(props: Any) -> JsxElement {
        return <div data-slot="table-container" className="relative w-full overflow-x-auto">
            <table
                {...props}
                data-slot="table"
                className={cn("w-full caption-bottom text-sm", props.className)}
            />
        </div>;
    }

    def:pub TableHeader(props: Any) -> JsxElement {
        return <thead
            {...props}
            data-slot="table-header"
            className={cn("[&_tr]:border-b", props.className)}
        />;
    }

    def:pub TableBody(props: Any) -> JsxElement {
        return <tbody
            {...props}
            data-slot="table-body"
            className={cn("[&_tr:last-child]:border-0", props.className)}
        />;
    }

    def:pub TableFooter(props: Any) -> JsxElement {
        return <tfoot
            {...props}
            data-slot="table-footer"
            className={cn("bg-muted/50 border-t font-medium [&>tr]:last:border-b-0", props.className)}
        />;
    }

    def:pub TableRow(props: Any) -> JsxElement {
        return <tr
            {...props}
            data-slot="table-row"
            className={cn("hover:bg-muted/50 data-[state=selected]:bg-muted border-b transition-colors", props.className)}
        />;
    }

    def:pub TableHead(props: Any) -> JsxElement {
        return <th
            {...props}
            data-slot="table-head"
            className={cn("text-foreground h-10 px-2 text-left align-middle font-medium whitespace-nowrap [&:has([role=checkbox])]:pr-0", props.className)}
        />;
    }

    def:pub TableCell(props: Any) -> JsxElement {
        return <td
            {...props}
            data-slot="table-cell"
            className={cn("p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0", props.className)}
        />;
    }

    def:pub TableCaption(props: Any) -> JsxElement {
        return <caption
            {...props}
            data-slot="table-caption"
            className={cn("text-muted-foreground mt-4 text-sm", props.className)}
        />;
    }
}
