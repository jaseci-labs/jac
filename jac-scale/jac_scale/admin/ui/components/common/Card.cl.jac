"""Card components for stats and content."""

cl {
    def:pub Card(children: any, className: str = "") -> JsxElement {
        return
            <div
                className={"bg-slate-900 border border-slate-800 rounded-lg " + className}
            >
                {children}
            </div>;
    }

    def:pub CardHeader(title: str, action: any = None) -> JsxElement {
        return
            <div
                className="flex items-center justify-between px-4 py-3 border-b border-slate-800"
            >
                <h2 className="text-sm font-medium text-white">
                    {title}
                </h2>
                {action}
            </div>;
    }

    def:pub CardBody(children: any, className: str = "p-4") -> JsxElement {
        return
            <div className={className}>
                {children}
            </div>;
    }

    def:pub StatsCard(label: str, value: any, color: str = "white") -> JsxElement {
        colorClasses = {
            "white": "text-white",
            "orange": "text-orange-500",
            "emerald": "text-emerald-500",
            "purple": "text-purple-500",
            "blue": "text-blue-500"
        };

        valueClass = "text-2xl font-semibold mt-1 " + (
            colorClasses[color] or "text-white"
        );

        return
            <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                <p className="text-xs text-slate-500 uppercase tracking-wider">
                    {label}
                </p>
                <p className={valueClass}>
                    {value}
                </p>
            </div>;
    }
}
