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
        inputClass = "w-full px-3 py-2 bg-surface-2 border border-line rounded-md text-fg text-sm placeholder:text-faint focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent transition-colors";

        return
            <div className={className}>
                {label
                and <label className="block text-xs font-medium text-muted mb-1.5">
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
        textareaClass = "w-full px-3 py-2 bg-surface-2 border border-line rounded-md text-fg text-sm font-mono placeholder:text-faint focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent transition-colors";

        return
            <div className={className}>
                {label
                and <label className="block text-xs font-medium text-muted mb-1.5">
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
