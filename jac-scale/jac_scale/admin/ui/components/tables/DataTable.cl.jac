"""Reusable data table component."""

def:pub DataTable(columns: list, children: any) -> JsxElement {
    return
        <table className="w-full">
            <thead>
                <tr className="border-b border-line">
                    {[
                        <th
                            key={col["key"]}
                            className={"px-4 py-2 text-xs font-medium text-faint uppercase tracking-wider " + (
                                col["align"] == "right" and "text-right" or "text-left"
                            )}
                        >
                            {col["label"]}
                        </th> for col in columns
                    ]}
                </tr>
            </thead>
            <tbody>{children}</tbody>
        </table>;
}

def:pub TableRow(children: any, className: str = "") -> JsxElement {
    return
        <tr className={"border-b border-line hover:bg-surface-2 " + className}>
            {children}
        </tr>;
}

def:pub TableCell(children: any, align: str = "left") -> JsxElement {
    alignClass = align == "right" and "text-right" or "text-left";
    return <td className={"px-4 py-3 " + alignClass}>{children}</td>;
}
