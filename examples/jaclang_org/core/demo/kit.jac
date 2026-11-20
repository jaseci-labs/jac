"""The markup the shared demo draws with, styled by `demo.css`."""

import "./demo.css";

def Card(children: any) -> JsxElement {
    return <div className="demo-card">{children}</div>;
}

def Line(children: any) -> JsxElement {
    return <div className="demo-line">{children}</div>;
}

def Title(children: any) -> JsxElement {
    return <div className="demo-title">{children}</div>;
}

def Label(children: any) -> JsxElement {
    return <span>{children}</span>;
}

def Btn(label: str, press: Callable) -> JsxElement {
    return <button className="demo-btn" onClick={press}>{label}</button>;
}
