"""Empty state and placeholder components."""

cl {
    def:pub EmptyState(title: str = "", message: str = "Coming soon") -> JsxElement {
        return
            <div className="p-8 text-center">
                {title
                and <h3 className="text-sm font-medium text-white mb-1">
                    {title}
                </h3>}
                <p className="text-slate-500 text-sm">
                    {message}
                </p>
            </div>;
    }

    def:pub PlaceholderCard(
        title: str, message: str = "Coming soon", action: any = None
    ) -> JsxElement {
        return
            <div
                className="bg-slate-900 border border-slate-800 rounded-lg overflow-hidden"
            >
                <div
                    className="flex items-center justify-between px-4 py-3 border-b border-slate-800"
                >
                    <h2 className="text-sm font-medium text-white">
                        {title}
                    </h2>
                    {action}
                </div>
                <EmptyState message={message}/>
            </div>;
    }
}
