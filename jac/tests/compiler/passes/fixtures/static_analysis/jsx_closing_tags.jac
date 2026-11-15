"""JSX closing tags name the element their opening tag opened."""

def:pub Card(children: any = None) -> JsxElement {
    <section className="card">{children}</section>
}

def:pub Panel(label: str) -> JsxElement {
    <div>
        <Card>
            <button type="button">{label}</button>
        </Card>
        <span>{label}</span>
    </div>
}

def:pub Broken -> JsxElement {
    <Missing>
        <p>text</p>
    </Missing>
}
