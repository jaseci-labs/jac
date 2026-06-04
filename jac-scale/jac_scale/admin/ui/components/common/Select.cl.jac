"""Reusable select dropdown component."""

cl {
    def:pub Select(
        value: str, onChange: any, options: list, label: str = "", className: str = ""
    ) -> JsxElement {
        selectClass = "w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-white text-sm focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/30 transition-colors";

        return
            <div className={className}>
                {label
                and <label
                    className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider"
                >
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
                className="px-2 py-1 bg-slate-950 border border-slate-700 rounded-lg text-white text-xs focus:outline-none focus:border-indigo-500 transition-colors"
            >
                {[
                    <option key={opt["value"]} value={opt["value"]}>
                        {opt["label"]}
                    </option> for opt in options
                ]}
            </select>;
    }
}
