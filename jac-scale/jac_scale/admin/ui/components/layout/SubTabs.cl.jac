"""Sub-tab navigation pills."""

cl {
    def:pub SubTabs(tabs: list, activeTab: str, onTabChange: any) -> JsxElement {
        def makeHandler(tabId: str) -> any {
            return lambda e: any  -> None { onTabChange(tabId);};
        }

        return
            <div className="flex px-4 gap-1 bg-slate-950/50">
                {[
                    <button
                        key={tab["id"]}
                        onClick={makeHandler(tab["id"])}
                        className={"px-3 py-1.5 text-xs font-medium rounded transition " + (
                            activeTab == tab["id"]
                            and "bg-slate-800 text-white"
                            or "text-slate-500 hover:text-slate-300 hover:bg-slate-800/50"
                        )}
                    >
                        {tab["label"]}
                    </button> for tab in tabs
                ]}
            </div>;
    }
}
