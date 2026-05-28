cl import from ...lib.utils { cn }

cl {
    def:pub Table(props: Any) -> JsxElement {
        return
            <div data-slot="table-container" className="cn-table-container">
                <table
                    {...props}
                    data-slot="table"
                    className={cn("cn-table", props.className)}
                />
            </div>;
    }

    def:pub TableHeader(props: Any) -> JsxElement {
        return
            <thead
                {...props}
                data-slot="table-header"
                className={cn("cn-table-header", props.className)}
            />;
    }

    def:pub TableBody(props: Any) -> JsxElement {
        return
            <tbody
                {...props}
                data-slot="table-body"
                className={cn("cn-table-body", props.className)}
            />;
    }

    def:pub TableFooter(props: Any) -> JsxElement {
        return
            <tfoot
                {...props}
                data-slot="table-footer"
                className={cn("cn-table-footer", props.className)}
            />;
    }

    def:pub TableRow(props: Any) -> JsxElement {
        return
            <tr
                {...props}
                data-slot="table-row"
                className={cn("cn-table-row", props.className)}
            />;
    }

    def:pub TableHead(props: Any) -> JsxElement {
        return
            <th
                {...props}
                data-slot="table-head"
                className={cn("cn-table-head", props.className)}
            />;
    }

    def:pub TableCell(props: Any) -> JsxElement {
        return
            <td
                {...props}
                data-slot="table-cell"
                className={cn("cn-table-cell", props.className)}
            />;
    }

    def:pub TableCaption(props: Any) -> JsxElement {
        return
            <caption
                {...props}
                data-slot="table-caption"
                className={cn("cn-table-caption", props.className)}
            />;
    }
}
