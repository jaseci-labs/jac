"""Reusable select dropdown component."""

cl {
    def:pub Select(
        value: str, onChange: any, options: list, label: str = "", className: str = ""
    ) -> JsxElement {
        selectClass = "w-full px-3 py-2 bg-surface-2 border border-line rounded-md text-fg text-sm focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent transition-colors";

        return
            <div className={className}>
                {label
                and <label className="block text-xs font-medium text-muted mb-1.5">
                    {label}
                </label>}
                <select value={value} onChange={onChange} className={selectClass}>
                    {[
                        <option key={opt["value"]} value={opt["value"]}>
                            {opt["label"]}
                        </option> for opt in options
                    ]}
                </select>
            </div>;
    }

    def:pub SmallSelect(value: str, onChange: any, options: list) -> JsxElement {
        return
            <select
                value={value}
                onChange={onChange}
                className="px-2 py-1 bg-surface-2 border border-line rounded-md text-fg text-xs focus:outline-none focus:border-accent transition-colors"
            >
                {[
                    <option key={opt["value"]} value={opt["value"]}>
                        {opt["label"]}
                    </option> for opt in options
                ]}
            </select>;
    }
}
