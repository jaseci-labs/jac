"""Reusable data table component."""

cl {
    def:pub DataTable(columns: list, children: any) -> JsxElement {
        return
            <table className="w-full">
                <thead>
                    <tr className="border-b border-slate-800">
                        {[
                            <th
                                key={col["key"]}
                                className={"px-4 py-2 text-xs font-medium text-slate-500 uppercase tracking-wider " + (
                                    col["align"] == "right"
                                    and "text-right"
                                    or "text-left"
                                )}
                            >
                                {col["label"]}
                            </th> for col in columns
                        ]}
                    </tr>
                </thead>
                <tbody>
                    {children}
                </tbody>
            </table>;
    }

    def:pub TableRow(children: any, className: str = "") -> JsxElement {
        return
            <tr
                className={"border-b border-slate-800/50 hover:bg-slate-800/30 " + className}
            >
                {children}
            </tr>;
    }

    def:pub TableCell(children: any, align: str = "left") -> JsxElement {
        alignClass = align == "right" and "text-right" or "text-left";
        return
            <td className={"px-4 py-3 " + alignClass}>
                {children}
            </td>;
    }
}
