"""Reusable input component with label."""

cl {
    def:pub Input(
        value: str,
        onChange: any,
        label: str = "",
        type: str = "text",
        placeholder: str = "",
        className: str = ""
    ) -> JsxElement {
        inputClass = "w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm placeholder-slate-600 focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500 transition";

        return
            <div className={className}>
                {label
                and <label
                    className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider"
                >
                    {label}
                </label>}
                <input
                    type={type}
                    value={value}
                    onChange={onChange}
                    placeholder={placeholder}
                    className={inputClass}
                />
            </div>;
    }

    def:pub TextArea(
        value: str,
        onChange: any,
        label: str = "",
        placeholder: str = "",
        rows: int = 4,
        className: str = ""
    ) -> JsxElement {
        textareaClass = "w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded text-white text-sm font-mono placeholder-slate-600 focus:outline-none focus:border-orange-500 transition";

        return
            <div className={className}>
                {label
                and <label
                    className="block text-xs font-medium text-slate-400 mb-1.5 uppercase tracking-wider"
                >
                    {label}
                </label>}
                <textarea
                    value={value}
                    onChange={onChange}
                    placeholder={placeholder}
                    rows={rows}
                    className={textareaClass}
                ></textarea>
            </div>;
    }
}
