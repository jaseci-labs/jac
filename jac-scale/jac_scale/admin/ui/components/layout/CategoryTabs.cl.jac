"""Main category tab navigation."""

cl {
    def:pub CategoryTabs(
        categories: list, activeCategory: str, onCategoryChange: any
    ) -> JsxElement {
        def makeHandler(catId: str, defaultTab: str) -> any {
            return lambda e: any  -> None { onCategoryChange(catId, defaultTab);};
        }

        return
            <div className="flex px-4 gap-1 border-t border-slate-800 bg-slate-900/50">
                {[
                    <button
                        key={cat["id"]}
                        onClick={makeHandler(cat["id"], cat["default"])}
                        className={"px-3 py-2 text-xs font-medium transition " + (
                            activeCategory == cat["id"]
                            and "text-orange-500 border-b-2 border-orange-500 -mb-px"
                            or "text-slate-500 hover:text-slate-300"
                        )}
                    >
                        {cat["label"]}
                    </button> for cat in categories
                ]}
            </div>;
    }
}
