"""Card components for stats and content."""

def:pub Card(children: any, className: str = "") -> JsxElement {
    return
        <div
            className={"bg-surface border border-line rounded-lg shadow-sm " + className}
        >
            {children}
        </div>;
}

def:pub CardHeader(title: str, action: any = None) -> JsxElement {
    return
        <div
            className="flex items-center justify-between px-5 py-3.5 border-b border-line"
        >
            <h2 className="text-sm font-medium text-fg">{title}</h2>
            {action}
        </div>;
}

def:pub CardBody(children: any, className: str = "p-4") -> JsxElement {
    return <div className={className}>{children}</div>;
}

def:pub StatsCard(label: str, value: any, color: str = "white") -> JsxElement {
    # Restrained palette: accent for highlights, success for state,
    # everything else falls back to plain foreground.
    colorClasses = {
        "white": "text-fg",
        "orange": "text-accent",
        "indigo": "text-accent",
        "emerald": "text-success",
        "purple": "text-fg",
        "blue": "text-fg"
    };

    valueClass = "text-2xl font-semibold mt-1 tracking-tight " + (
        colorClasses[color] or "text-fg"
    );

    return
        <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
            <p className="text-[11px] text-faint uppercase tracking-wider font-medium">
                {label}
            </p>
            <p className={valueClass}>{value}</p>
        </div>;
}
