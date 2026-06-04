"""Card components for stats and content."""

cl {
    def:pub Card(children: any, className: str = "") -> JsxElement {
        return
            <div
                className={"bg-slate-900/70 border border-white/[0.06] rounded-xl shadow-sm shadow-black/20 " + className}
            >
                {children}
            </div>;
    }

    def:pub CardHeader(title: str, action: any = None) -> JsxElement {
        return
            <div
                className="flex items-center justify-between px-5 py-3.5 border-b border-white/[0.06]"
            >
                <h2 className="text-sm font-medium text-white">{title}</h2>
                {action}
            </div>;
    }

    def:pub CardBody(children: any, className: str = "p-4") -> JsxElement {
        return <div className={className}>{children}</div>;
    }

    def:pub StatsCard(label: str, value: any, color: str = "white") -> JsxElement {
        colorClasses = {
            "white": "text-white",
            "orange": "text-indigo-400",
            "indigo": "text-indigo-400",
            "emerald": "text-emerald-400",
            "purple": "text-violet-400",
            "blue": "text-sky-400"
        };

        valueClass = "text-2xl font-semibold mt-1 tracking-tight " + (
            colorClasses[color] or "text-white"
        );

        return
            <div className="bg-slate-900/70 border border-white/[0.06] rounded-xl p-4 shadow-sm shadow-black/20">
                <p className="text-[11px] text-slate-500 uppercase tracking-wider font-medium">
                    {label}
                </p>
                <p className={valueClass}>{value}</p>
            </div>;
    }
}
