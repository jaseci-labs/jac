"""Card, CardHeader, CardBody layout components."""
def:pub Card(children: Any, className: str = "") -> JsxElement {
    return
        <div className={"bg-slate-900 border border-slate-800 rounded-lg " + className}>
            {children}
        </div>;
}

def:pub CardHeader(title: str, subtitle: str = "") -> JsxElement {
    return
        <div className="px-4 py-3 border-b border-slate-800">
            <h2 className="text-sm font-semibold text-white">{title}</h2>
            {(<p className="text-xs text-slate-500 mt-0.5">{subtitle}</p>)
                if subtitle
                else None}
        </div>;
}

def:pub CardBody(children: Any, className: str = "p-4") -> JsxElement {
    return
        <div className={className}>{children}</div>;
}
