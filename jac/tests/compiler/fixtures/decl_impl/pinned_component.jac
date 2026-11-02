def:pub Field(value: str, onBioChange: any) -> JsxElement {
    return <span>{value}</span>;
}

def:pub Editor -> JsxElement;

impl Editor -> JsxElement {
    has bioText: str = "";
    return <Field value={bioText} onBioChange={lambda (t: str) { bioText = t; }}/>;
}
