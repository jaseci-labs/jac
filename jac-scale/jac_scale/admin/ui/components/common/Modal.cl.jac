"""Modal dialog component."""

def:pub Modal(isOpen: bool, onClose: any, title: str, children: any) -> JsxElement {
    if not isOpen {
        return <></>;
    }

    return
        <div
            className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4"
        >
            <div
                className="bg-surface border border-line rounded-lg w-full max-w-sm shadow-md"
            >
                <div className="px-4 py-3 border-b border-line">
                    <h2 className="text-sm font-medium text-fg">{title}</h2>
                </div>
                <div className="p-4">{children}</div>
            </div>
        </div>;
}

def:pub ModalFooter(children: any) -> JsxElement {
    return <div className="flex gap-2 justify-end mt-4">{children}</div>;
}
