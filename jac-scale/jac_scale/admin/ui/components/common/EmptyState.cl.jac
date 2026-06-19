"""Empty state and placeholder components."""

def:pub EmptyState(title: str = "", message: str = "Coming soon") -> JsxElement {
    return
        <div className="p-8 text-center">
            {title and <h3 className="text-sm font-medium text-fg mb-1">{title}</h3>}
            <p className="text-muted text-sm">{message}</p>
        </div>;
}

def:pub PlaceholderCard(
    title: str, message: str = "Coming soon", action: any = None
) -> JsxElement {
    return
        <div className="bg-surface border border-line rounded-lg overflow-hidden">
            <div
                className="flex items-center justify-between px-4 py-3 border-b border-line"
            >
                <h2 className="text-sm font-medium text-fg">{title}</h2>
                {action}
            </div>
            <EmptyState message={message}/>
        </div>;
}
